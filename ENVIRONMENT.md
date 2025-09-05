# Environment and Tooling

This document lists the tools, versions, and environment configurations required to run this project.

## Tool Versions
* Terraform: `v1.13.1`
* AWS CLI: `v2.27.8`
* Docker: `v28.3.2`
* Git: `v2.49.0`
* Cosign: `v3.x` (Used in the CI/CD pipeline)

---
## AWS Configuration
* Region: `us-east-1`

---
## Secrets
The following secret name/path is used in AWS Secrets Manager. The value is managed within AWS.
* `/dockyard/SUPER_SECRET_TOKEN`
