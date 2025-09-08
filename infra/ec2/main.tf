resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "podinfo-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-b" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "podinfo-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "public-route-table" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "podinfo-alb-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow HTTP traffic to ALB"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2" {
  name        = "podinfo-ec2-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow traffic from ALB to EC2"
  ingress {
    from_port       = 8080 // The port podinfo runs on
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "main" {
  name               = "podinfo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "blue" {
  name     = "podinfo-blue-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/healthz"
  }
}

resource "aws_lb_target_group" "green" {
  name     = "podinfo-green-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/healthz"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.id
  }
}

resource "aws_launch_template" "main" {
  name_prefix   = "podinfo-"
  image_id      = var.ami_id
  instance_type = "t3.micro" // Sticking to the free tier
  user_data     = filebase64("${path.module}/user-data.sh")

  vpc_security_group_ids = [aws_security_group.ec2.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
}

resource "aws_autoscaling_group" "main" {
  name                = "podinfo-asg"
  desired_capacity    = 2
  max_size            = 5
  min_size            = 2
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  default_cooldown    = 120
  target_group_arns = [aws_lb_target_group.blue.arn]
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "podinfo-ec2-instance-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" // Good for debugging
}
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "podinfo-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

data "aws_iam_policy_document" "secret_read_policy" {
  statement {
    sid    = "AllowSecretRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "*" # In a real prod environment, you would lock this down to the secret's ARN
    ]
  }
}

resource "aws_iam_policy" "secret_read" {
  name   = "podinfo-secret-read-policy"
  policy = data.aws_iam_policy_document.secret_read_policy.json
}

resource "aws_iam_role_policy_attachment" "ec2_secret_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secret_read.arn
}

resource "aws_autoscaling_policy" "alb_requests_policy" {
  name                   = "alb-requests-per-target-policy"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.blue.arn_suffix}"
    }

    target_value = 100.0

  }
}
