# ==============================================================================
# Dynatrace OneAgent ECS Daemon Service Configuration
# ==============================================================================

# Data source to fetch the details of the existing ECS cluster.
# This ensures that the cluster exists and validates the name.
data "aws_ecs_cluster" "target" {
  cluster_name = var.ecs_cluster_name
}

# ------------------------------------------------------------------------------
# Dynatrace OneAgent Task Definition
# ------------------------------------------------------------------------------
# The task definition specifies how the OneAgent container is configured.
# Since it needs to monitor the host and all containers running on it, it must run
# in the host network/PID/IPC namespaces and be execution-privileged.
resource "aws_ecs_task_definition" "oneagent" {
  family                   = "dynatrace-oneagent"
  network_mode             = "host"
  pid_mode                 = "host"
  ipc_mode                 = "host"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  # Volume definition to mount the host root directory.
  # This allows the agent to inspect files, configurations, and logs on the host.
  volume {
    name      = "host_root"
    host_path = "/"
  }

  container_definitions = jsonencode([
    {
      name      = "dynatrace-oneagent"
      image     = var.oneagent_image
      essential = true
      privileged = true

      # Resource reservations for the agent. Using a soft memory limit (reservation)
      # ensures the container doesn't get forcefully terminated if memory spikes,
      # while not blocking ECS instance registration capacity.
      cpu               = 100
      memoryReservation = 256

      # Mount the host root filesystem to /mnt/root in the container (read-only).
      mountPoints = [
        {
          sourceVolume  = "host_root"
          containerPath = "/mnt/root"
          readOnly      = true
        }
      ]

      # Configuration parameters passed to the container installer script.
      environment = [
        {
          name  = "ONEAGENT_INSTALLER_TOKEN"
          value = var.dynatrace_api_token
        },
        {
          name  = "ONEAGENT_INSTALLER_SCRIPT_URL"
          value = "${var.dynatrace_environment_url}/api/v1/deployment/installer/agent/unix/default/latest?arch=x86&flavor=default&Api-Token=${var.dynatrace_api_token}"
        }
      ]
    }
  ])
}

# ------------------------------------------------------------------------------
# Dynatrace OneAgent ECS Service (DAEMON strategy)
# ------------------------------------------------------------------------------
# Using the DAEMON scheduling strategy ensures that exactly one task of the
# OneAgent runs on each EC2 container instance in the ECS cluster.
# ECS automatically launches a OneAgent task on any new instance added to the cluster.
resource "aws_ecs_service" "oneagent" {
  name                = "dynatrace-oneagent"
  cluster             = data.aws_ecs_cluster.target.arn
  task_definition     = aws_ecs_task_definition.oneagent.arn
  scheduling_strategy = "DAEMON"
  launch_type         = "EC2"

  # Since scheduling_strategy is DAEMON, desired_count is managed by AWS and
  # must not be defined in the configuration.
  lifecycle {
    ignore_changes = [desired_count]
  }
}
