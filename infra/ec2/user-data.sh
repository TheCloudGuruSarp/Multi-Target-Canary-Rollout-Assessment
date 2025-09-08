set -e

yum update -y
yum install -y docker ruby wget
service docker start
usermod -a -G docker ec2-user

CODEDEPLOY_BUCKET="aws-codedeploy-us-east-1" # Change if in a different region
CODEDEPLOY_KEY="latest/install"
wget "https://${CODEDEPLOY_BUCKET}.s3.amazonaws.com/${CODEDEPLOY_KEY}"
chmod +x ./install
./install auto

yum install -y amazon-cloudwatch-agent

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
