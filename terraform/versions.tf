terraform {
  required_version = ">= 1.0.0"

  # Terraform Cloud — remote state (and CLI-driven runs).
  # Organization, workspace, and hostname are supplied at `terraform init`
  # time via env vars in CI (set in .github/workflows/deploy.yml):
  #   TF_CLOUD_ORGANIZATION, TF_WORKSPACE, TF_CLOUD_HOSTNAME
  # The workspace must use "Local" execution mode: this pipeline reads
  # `terraform output` and runs AWS CLI on the runner, and passes AWS
  # credentials as runner env vars — remote execution would not see them.
  cloud {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}
