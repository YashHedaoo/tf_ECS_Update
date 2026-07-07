# ==============================================================================
# Required inputs
# ==============================================================================

variable "ecs_cluster_name" {
  type        = string
  description = "The name of the existing EC2-backed ECS cluster to install OneAgent onto."
}

variable "dynatrace_environment_url" {
  type        = string
  description = "The Dynatrace environment URL (e.g., https://abc12345.live.dynatrace.com)."
}

variable "dynatrace_api_token" {
  type        = string
  description = "The Dynatrace PaaS/API token used to download the installer."
  sensitive   = true
}

# ==============================================================================
# Optional (defaulted — normally left untouched)
# ==============================================================================

variable "aws_region" {
  type        = string
  description = "The AWS Region where the ECS Cluster is located."
  default     = "us-east-1"
}

variable "application_service_name" {
  type        = string
  description = "Optional application ECS service to force-restart so its already-running containers get instrumented. Leave empty to skip the restart."
  default     = ""
}
