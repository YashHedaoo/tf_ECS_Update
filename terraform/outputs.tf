output "oneagent_task_definition_arn" {
  description = "The ARN of the registered Dynatrace OneAgent task definition."
  value       = aws_ecs_task_definition.oneagent.arn
}

output "oneagent_service_name" {
  description = "The name of the Dynatrace OneAgent ECS service."
  value       = aws_ecs_service.oneagent.name
}

output "oneagent_service_cluster" {
  description = "The ARN of the cluster where the Dynatrace OneAgent service is deployed."
  value       = data.aws_ecs_cluster.target.arn
}
