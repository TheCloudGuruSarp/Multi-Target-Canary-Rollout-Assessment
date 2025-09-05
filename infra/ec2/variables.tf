// Define the Amazon Machine Image (AMI) for our EC2 instances.
// We're using a standard Amazon Linux 2 AMI for us-east-1.
// If you use a different region, you'll need to find the correct AMI ID.
variable "ami_id" {
  description = "The AMI ID for EC2 instances (Amazon Linux 2)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" // us-east-1
}
