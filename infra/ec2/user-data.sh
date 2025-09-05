#!/bin/bash
set -e

# Install necessary packages and Docker
yum update -y
yum install -y docker ruby wget
service docker start
usermod -a -G docker ec2-user

# Install the CodeDeploy agent
CODEDEPLOY_BUCKET="aws-codedeploy-us-east-1" # Change if in a different region
CODEDEPLOY_KEY="latest/install"
wget "https://${CODEDEPLOY_BUCKET}.s3.amazonaws.com/${CODEDEPLOY_KEY}"
chmod +x ./install
./install auto

# Install the CloudWatch agent
yum install -y amazon-cloudwatch-agent
