output "project_id" {
  value = railway_project.sample_api.id
}

output "chaos_id" {
  value = railway_service.chaos_monkey_service.id
}

output "dd_service_id" {
  value = railway_service.datadog_agent.id
}
