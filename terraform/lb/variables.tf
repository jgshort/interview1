variable "environment" {
  type = string
}

variable "load_balancer_name" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

variable "railway_domains" {
  type = list(string)
}

