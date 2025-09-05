Multi-target Canary Rollout

This project implements a reproducible, secure deployment system that builds, signs, and ships a container from GitHub Actions into AWS, then rolls it out in parallel to AWS Lambda and a dual-host EC2/ALB stack.

## Architecture Diagram
![Architecture](docs/diagram.png)

---
## Prerequisites
* An AWS account with Administrator privileges.
* A GitHub account.
* Locally installed tools as specified in `ENVIRONMENT.md`.
* A GitHub Personal Access Token (PAT) with `repo` scope for `gh auth login`.

---
## 1. Bootstrap (Sıfırdan Kurulum)
1.  **Clone the Repository:**
    ```bash
    git clone <your-repo-url>
    cd <repo-name>
    ```
2.  **Configure AWS CLI:**
    Ensure your local AWS CLI is configured with credentials for your AWS account.
    ```bash
    aws configure
    ```
3.  **Create Terraform Backend Resources:**
    Manually create an S3 bucket and a DynamoDB table to store the Terraform state.
    ```bash
    # Replace 'your-unique-bucket-name' with a unique name
    aws s3api create-bucket --bucket your-unique-bucket-name --region us-east-1
    aws dynamodb create-table --table-name terraform-lock-table --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region us-east-1
    ```
4.  **Update Terraform Files:**
    Update the `backend` blocks in all Terraform files (`infra/**`) with your S3 bucket and DynamoDB table names. Also, update any other placeholders like AWS Account ID.
5.  **Apply Terraform Stacks (in order):**
    ```bash
    # Global Stack
    cd infra/global
    terraform init && terraform apply --auto-approve

    # EC2 Stack
    cd ../ec2
    terraform init && terraform apply --auto-approve

    # Lambda Stack
    cd ../lambda
    terraform init && terraform apply --auto-approve
    ```
6.  **Setup GitHub Secrets:**
    In the GitHub repository settings, add the `AWS_IAM_ROLE_ARN` secret with the value from the `global` stack's Terraform output.

---
## 2. Operate (Kullanım ve Dağıtım)
The CI/CD pipeline is fully automated. To trigger a new deployment to the `development` environment:
1.  Make a code change.
2.  Push the change to the `main` branch.
    ```bash
    git push origin main
    ```
This will trigger the `build-and-push.yml` workflow, which upon success will trigger the `deploy.yml` workflow, deploying to both EC2 and Lambda targets.

---
## 3. Promote to Production (Prod'a Yükseltme)
1.  After a successful deployment to the `dev` environment, the `deploy.yml` workflow will pause at the "Approve for Production" step.
2.  Go to the "Actions" tab in the GitHub repository.
3.  Find the running workflow and click "Review deployments".
4.  Select the "production" environment and click "Approve and deploy".

---
## 4. Destroy (Altyapıyı Temizleme)
To avoid incurring costs, destroy all created infrastructure by running `terraform destroy` in the reverse order of creation.
```bash
# Lambda Stack
cd infra/lambda
terraform destroy --auto-approve

# EC2 Stack
cd ../ec2
terraform destroy --auto-approve

# Global Stack
cd ../global
terraform destroy --auto-approve
