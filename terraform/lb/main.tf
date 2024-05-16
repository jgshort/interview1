terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    encrypt        = true
    dynamodb_table = "SampleLbTerraformLock"
    bucket         = "sample-interview-project"
    key            = "sample-lb-terraform.tfstate"
    region         = "us-east-1"
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "null_resource" "cloudflare_domains" {
  for_each = toset(var.railway_domains)

  provisioner "local-exec" {
    command     = "echo ${each.value}"
    interpreter = ["bash", "-c"]
  }
}

resource "cloudflare_load_balancer_pool" "sample_api_load_balancer_pool" {
  account_id         = var.cloudflare_account_id
  name               = "sample-api-load-balancer-pool"
  description        = "Balances traffic between n-available Railway services."
  enabled            = true
  minimum_origins    = 1
  notification_email = "53501+jgshort@users.noreply.github.com"
  monitor            = cloudflare_load_balancer_monitor.sample_api_load_balancer_monitor.id

  dynamic "origins" {
    for_each = toset(var.railway_domains)
    content {
      name    = "railway-service-${replace(origins.value, ".", "-")}"
      address = origins.value
      enabled = true
      header {
        header = "Host"
        values = [origins.value]
      }
    }
  }

  origin_steering {
    policy = "random"
  }
}

resource "cloudflare_load_balancer" "sample_api_load_balancer" {
  zone_id          = var.cloudflare_zone_id
  name             = var.load_balancer_name
  fallback_pool_id = cloudflare_load_balancer_pool.sample_api_load_balancer_pool.id
  default_pool_ids = [cloudflare_load_balancer_pool.sample_api_load_balancer_pool.id]
  description      = "The Sample API Load Balancer"
  proxied          = true
}

resource "cloudflare_load_balancer_monitor" "sample_api_load_balancer_monitor" {
  account_id     = var.cloudflare_account_id
  type           = "https"
  expected_codes = "2xx"
  method         = "GET"
  timeout        = 7
  path           = "/health"
  interval       = 60
  retries        = 5
  description    = "The Sample API Load Balancer Monitor"
  header {
    header = "Host"
    values = [var.load_balancer_name]
  }
  allow_insecure   = false
  follow_redirects = true
}
