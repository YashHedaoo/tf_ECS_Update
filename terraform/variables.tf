variable "aws_region" {
  type        = string
  description = "The AWS Region where the ECS Cluster is located."
}

variable "ecs_cluster_name" {
  type        = string
  description = "The name of the existing ECS cluster where OneAgent will be deployed."
}

variable "application_service_name" {
  type        = string
  description = "The name of the existing application ECS service to be restarted after OneAgent deployment."
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

variable "oneagent_image" {
  type        = string
  description = "The Dynatrace OneAgent Docker image to use."
  default     = "dynatrace/oneagent:latest"
}

variable "oneagent_installer_arch" {
  type        = string
  description = "CPU architecture for the OneAgent installer. Use 'x86' for Intel/AMD EC2 instances or 'arm' for Graviton (ARM) instances."
  default     = "x86"

  validation {
    condition     = contains(["x86", "arm"], var.oneagent_installer_arch)
    error_message = "oneagent_installer_arch must be either 'x86' or 'arm'."
  }
}

variable "ecs_execution_role_arn" {
  type        = string
  description = "The ARN of the existing IAM Execution Role for ECS tasks."
}

variable "ecs_task_role_arn" {
  type        = string
  description = "The ARN of the existing IAM Task Role for ECS tasks (optional)."
  default     = null
}
