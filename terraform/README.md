# Dynatrace OneAgent ECS Daemon Service Deployment

This project provides a production-grade Terraform configuration and a streamlined GitHub Actions workflow to deploy Dynatrace OneAgent as an ECS Daemon Service on ECS EC2 Container Instances. It automatically schedules one OneAgent task per host to monitor container metrics, network, and processes, and triggers a rolling restart of your application service to initiate tracing.

## Project Structure

```text
.github/
└── workflows/
    └── deploy.yml          # Single-stage GitHub Actions workflow file

terraform/
├── main.tf                 # Registers the task definition and deploys the Daemon service
├── variables.tf            # Variables configuration
├── outputs.tf              # Outputs (Task Definition ARN, Service Name, etc.)
├── provider.tf             # AWS Provider details
├── versions.tf             # Version constraints (Terraform & AWS Provider)
├── terraform.tfvars.example # Boilerplate example variables file
└── README.md               # Setup and verification instructions (This file)
```

---

## Required GitHub Secrets

To run the GitHub Actions deployment pipeline, configure the following secrets in your GitHub Repository under **Settings > Secrets and variables > Actions > Secrets**:

| Secret Name | Required? | Description | Example |
| :--- | :--- | :--- | :--- |
| `AWS_ACCESS_KEY_ID` | **Required** | AWS access key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | **Required** | AWS secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `ECS_CLUSTER_NAME` | **Required** | Name of the target active ECS EC2 cluster | `prod-cluster` |
| `DYNATRACE_ENVIRONMENT_URL` | **Required** | Dynatrace tenant environment URL | `https://abc12345.live.dynatrace.com` |
| `DYNATRACE_API_TOKEN` | **Required** | Dynatrace PaaS/API download token | `dt0c01.xxxxxxxx.xxxxxx` |
| `AWS_REGION` | Optional | AWS region (defaults to `us-east-1`) | `us-east-1` |
| `APPLICATION_SERVICE_NAME` | Optional | App ECS service to restart; omit to only install the agent | `frontend-service` |

---

## Terraform Variables

If running locally (using `terraform.tfvars`):

| Variable Name | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `ecs_cluster_name` | `string` | Target ECS cluster | *None (Required)* |
| `dynatrace_environment_url`| `string` | Dynatrace environment base URL | *None (Required)* |
| `dynatrace_api_token` | `string` | Dynatrace PaaS/API token (Sensitive) | *None (Required)* |
| `aws_region` | `string` | Target AWS region | `us-east-1` |
| `application_service_name`| `string` | App ECS service to restart (empty = skip) | `""` |

The OneAgent image (`dynatrace/oneagent:latest`) and installer architecture (`x86`) are set directly in `main.tf` — edit there if you need to pin a version or target Graviton/ARM hosts (`arch=arm`).

---

## How to Run Locally

To deploy the OneAgent infrastructure locally, navigate to the `terraform/` directory and perform these steps:

1. **Configure Environment Variables / tfvars:**
   Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   Open `terraform.tfvars` and update the values with your infrastructure details.

2. **Initialize Terraform:**
   Initialize the workspace, backend, and download the AWS provider plugins.
   ```bash
   terraform init
   ```

3. **Validate the Configuration:**
   Check for syntax errors or invalid declarations.
   ```bash
   terraform validate
   ```

4. **Plan Execution:**
   Review resources to be created:
   ```bash
   terraform plan
   ```

5. **Apply Configuration:**
   Deploy the task definition and the ECS Daemon Service:
   ```bash
   terraform apply
   ```

6. **Trigger Application Restart (Optional CLI step):**
   ```bash
   aws ecs update-service \
     --cluster <ecs_cluster_name> \
     --service <application_service_name> \
     --force-new-deployment
   ```

---

## How the Pipeline Deploys the Daemon Service

The GitHub Actions pipeline is run inside a single job `Deploy to ECS` and executes sequentially:
1. **Validation & Configuration**: Checks for availability of all parameters and ensures the AWS CLI can describe the cluster and application service.
2. **Targeted Definition Registration**: Runs `terraform apply -target=aws_ecs_task_definition.oneagent` to build and register the Dynatrace container specification.
3. **Daemon Service Creation**: Applies the remaining Terraform resources. Since scheduling strategy is set to `DAEMON`, ECS starts a container on every registered container instance.
4. **Daemon Verification Loop**: Queries the running tasks on the OneAgent service and waits until they match the number of active container instances in the cluster.

---

## How the Application Restart Works

Dynatrace OneAgent monitors containers by dynamically injecting into their runtime. For this mechanism to trigger, application containers must start *after* the OneAgent process is running on the host. 
To ensure this:
1. Once the OneAgent daemon service reaches a stable running status, the pipeline issues a force-new-deployment command:
   ```bash
   aws ecs update-service --cluster <cluster> --service <app-service> --force-new-deployment
   ```
2. The pipeline blocks using `aws ecs wait services-stable` to verify that the application has replaced all tasks and fully stabilized.

---

## How to Verify Deployment

### 1. Verification in AWS ECS
- Open the AWS Console and go to **ECS > Clusters > [Your Cluster] > Services**.
- Check that the `dynatrace-oneagent` service has:
  - **Scheduling Strategy**: `DAEMON`
  - **Deployment Status**: Active
  - **Running Tasks**: Equals the number of EC2 Container Instances.
- Review task logs to confirm they connect successfully to the Dynatrace environment.

### 2. Verification in Dynatrace UI
- Log in to your Dynatrace tenant dashboard.
- Go to **Infrastructure > Hosts** or search for the EC2 container instances.
- You should see your ECS host instances listed and reporting full stack metrics.
- Navigate to **Containers** to check if all application containers running inside the ECS host are actively inspected.
