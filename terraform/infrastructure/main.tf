terraform {
  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "0.4.0"
    }
  }

  backend "s3" {
    encrypt        = true
    dynamodb_table = "SampleApiTerraformLock"
    bucket         = "sample-project"
    key            = "sample-api-terraform.tfstate"
    region         = "us-east-1"
  }
}

provider "railway" {
  token = var.railway_token
}

module "api" {
  source = "./modules/api"

  environment   = var.environment
  private       = true
  railway_token = var.railway_token
  service_count = 2
}

module "cdn" {
  source = "./modules/cdn"

  environment        = var.environment
  load_balancer_name = var.load_balancer_name
}

module "monitors" {
  source = "./modules/monitors"

  datadog_api_key    = var.datadog_api_key
  datadog_app_key    = var.datadog_app_key
  load_balancer_name = var.load_balancer_name
}

