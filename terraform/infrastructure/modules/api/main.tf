terraform {
  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "0.4.0"
    }
  }
}

provider "railway" {
  token = var.railway_token
}

resource "railway_project" "sample_api" {
  name        = "sample"
  description = "Sample API Project"

  default_environment = {
    name = var.environment
  }

  private = var.private
}

resource "railway_service" "sample_api_service" {
  count       = var.service_count
  name        = "Sample API ${count.index}"
  project_id  = railway_project.sample_api.id
  config_path = "railway.json"
}

resource "railway_service" "chaos_monkey_service" {
  name        = "Chaos Monkey"
  project_id  = railway_project.sample_api.id
  config_path = "railway.json"
}

resource "railway_service" "datadog_agent" {
  name       = "Datadog"
  project_id = railway_project.sample_api.id
}

