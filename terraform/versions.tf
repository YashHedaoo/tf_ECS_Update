terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  # Remote state backend (partial configuration).
  # Values are supplied at `terraform init` time so nothing environment-specific
  # is hardcoded here:
  #   - CI  : the pipeline passes -backend-config="bucket=..." etc. (see deploy.yml)
  #   - Local: run `terraform init -backend-config=backend.hcl` (see backend.hcl.example)
  # A remote backend is REQUIRED for the GitHub Actions pipeline so state persists
  # across runs; without it every run starts empty and re-creating the service fails.
  backend "s3" {}
}
