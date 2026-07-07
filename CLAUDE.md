# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Terraform + GitHub Actions to deploy **Dynatrace OneAgent as an ECS Daemon Service** onto ECS EC2 container instances, then force-restart a separate application ECS service so its containers boot under active OneAgent instrumentation. The repo provisions only the OneAgent daemon; the ECS cluster, container instances, and application service are pre-existing and referenced by name/ARN.

## Commands

All Terraform commands run from the `terraform/` directory.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then fill in values
terraform init
terraform validate
terraform fmt          # format check
terraform plan
terraform apply
```

There is no test suite, build step, or linter beyond `terraform validate` / `terraform fmt`.

The GitHub Actions pipeline (`.github/workflows/deploy.yml`) runs on push to `main` or via `workflow_dispatch`. It pins Terraform `1.7.0`; local `versions.tf` only requires `>= 1.0.0`.

## Architecture and non-obvious constraints

**Two-phase apply (deliberate).** The pipeline runs `terraform apply -target=aws_ecs_task_definition.oneagent` *before* a full `terraform apply`. Step 4 registers the task definition and exports its ARN; Step 5 then creates/updates the daemon service. If you change resource names or dependencies, keep this ordering intact or the pipeline's `terraform output -raw oneagent_task_definition_arn` lookups break.

**Host-level privileges are required, not optional.** The task definition (`terraform/main.tf`) uses `network_mode/pid_mode/ipc_mode = "host"`, `privileged = true`, and mounts host `/` to `/mnt/root` (read-only). OneAgent must see the host kernel and all sibling containers' processes to instrument them. Do not "harden" these away — the deployment stops working without them.

**DAEMON scheduling + `ignore_changes = [desired_count]`.** `aws_ecs_service.oneagent` uses `scheduling_strategy = "DAEMON"`, so AWS manages task count (one per container instance) and `desired_count` must never be set. The `lifecycle.ignore_changes` block on it exists for this reason — do not remove it or add `desired_count`.

**Ordering dependency between the two services.** OneAgent must already be running on a host before the application containers start, or instrumentation won't inject. This is why the pipeline force-restarts the application service (Step 6, `aws ecs update-service --force-new-deployment` + `aws ecs wait services-stable`) *after* verifying the daemon is stable. Terraform does not manage the application service — it's only ever restarted via AWS CLI in the pipeline.

**OneAgent config flows via container env vars**, not a config file: `ONEAGENT_INSTALLER_TOKEN` and `ONEAGENT_INSTALLER_SCRIPT_URL` (built from `dynatrace_environment_url` + `dynatrace_api_token`). The container downloads and runs the installer script at startup.

## Variables and secrets

Variables are defined in `terraform/variables.tf`. Required: `aws_region`, `ecs_cluster_name`, `application_service_name`, `ecs_execution_role_arn`, `dynatrace_environment_url`, `dynatrace_api_token` (sensitive). Optional: `ecs_task_role_arn` (default `null`), `oneagent_image` (default `dynatrace/oneagent:latest`).

In CI these come from GitHub Secrets, mapped to `TF_VAR_*` env vars in the workflow's top-level `env` block. Several have fallback defaults in the workflow (e.g. `AWS_REGION` → `us-east-1`, `ECS_CLUSTER_NAME` → `dev-cluster`) — a missing secret silently uses the default rather than failing, so verify secrets are set for real deployments.

When adding a variable, update all three: `terraform/variables.tf`, the `env:` block in `deploy.yml`, and `terraform/terraform.tfvars.example`.
