# Scalability Roadmap: Multi-Region Active/Active Architecture

This document outlines a plan to evolve the current single-region deployment into a highly available, multi-region active/active architecture.

### Target Architecture

The goal is to serve traffic from at least two AWS regions (e.g., us-east-1 and eu-west-1) simultaneously to improve global latency and provide disaster recovery.

1.  **Global Traffic Management:**
    * Utilize **AWS Route 53** with a **Latency-Based Routing** policy. This will automatically direct users to the region that provides the lowest latency for them. For failover, Route 53 health checks will be configured to automatically reroute traffic away from an unhealthy region.

2.  **Infrastructure Replication:**
    * The existing Terraform code will be refactored to use **Terraform Workspaces**. A workspace will be created for each region (e.g., `us-east-1`, `eu-west-1`), allowing us to deploy identical copies of our VPC, ALB, EC2, and Lambda stacks with region-specific variables.

3.  **Container Image Replication:**
    * The ECR repository in our primary region will be configured with **Cross-Region Replication**. This ensures that any image pushed to the `us-east-1` ECR is automatically replicated to the `eu-west-1` ECR, making the same immutable artifact available in both regions for deployment.

4.  **Environment and Account Isolation:**
    * For enhanced security and blast radius reduction, the `prod` environment will be moved to a completely separate AWS account from the `dev` environment. AWS Organizations and IAM roles will be used to manage cross-account access for the CI/CD pipeline.

### Risk & Cost Trade-offs

* **Costs:**
    * **Infrastructure:** Running a complete stack in a second region will roughly double the infrastructure costs for compute and networking.
    * **Data Transfer:** Cross-region data transfer (for ECR replication, potential database replication) incurs additional costs that must be monitored.

* **Risks & Complexity:**
    * **Stateful Services:** This plan primarily addresses stateless services. If a database is introduced, managing multi-region data consistency (e.g., using DynamoDB Global Tables or Aurora Global Database) becomes the main challenge and adds significant complexity.
    * **Operational Overhead:** Managing and monitoring a multi-region setup requires more sophisticated observability and a clear operational playbook for failover scenarios.
