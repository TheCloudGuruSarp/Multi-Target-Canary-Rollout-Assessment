set -e

AWS_REGION="us-east-1"
SECRET_NAME="/dockyard/SUPER_SECRET_TOKEN"
ECR_REPOSITORY_URI="727699166508.dkr.ecr.us-east-1.amazonaws.com/podinfo"
IMAGE_TAG=$(cat /tmp/image_tag.txt)

echo "Fetching secret from Secrets Manager..."
SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$AWS_REGION" --query SecretString --output text)

if [ -z "$SECRET_VALUE" ]; then
    echo "ERROR: Secret value is empty. Exiting."
    exit 1
fi

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPOSITORY_URI"

if [ "$(docker ps -q -f name=podinfo)" ]; then
    echo "Stopping and removing existing podinfo container..."
    docker stop podinfo
    docker rm podinfo
fi

echo "Pulling image ${ECR_REPOSITORY_URI}:${IMAGE_TAG}..."
docker pull "${ECR_REPOSITORY_URI}:${IMAGE_TAG}"

echo "Starting new podinfo container..."
docker run -d --name podinfo -p 8080:9898 \
  -e PODINFO_UI_MESSAGE="Hello from EC2!" \
  -e SUPER_SECRET_TOKEN="$SECRET_VALUE" \
  "${ECR_REPOSITORY_URI}:${IMAGE_TAG}"

echo "Deployment script finished successfully."
