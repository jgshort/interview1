terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.us5.datadoghq.com/"
}

resource "datadog_monitor" "cloudflare_load_balancer_monitor" {
  name    = "Cludflare Load Balancer Healthy"
  type    = "service check"
  message = "Cloudflare load balancer unhealthy! Check origins."

  query = "\"http.can_connect\".over(\"instance:sample_load_balancer\",\"url:https://${var.load_balancer_name}/health\").by(\"*\").last(1).pct_by_status()"

  monitor_thresholds {
    warning  = 3
    critical = 5
  }

  // Mostly arbitrary for the sake of this assessment:
  new_group_delay     = 120
  no_data_timeframe   = 5
  notify_no_data      = false
  notify_audit        = false
  timeout_h           = 24
  require_full_window = true
  renotify_interval   = 15
  include_tags        = false
}

resource "datadog_monitor" "sampel_api_service_monitors" {
  count   = 2
  name    = "Sample API Service ${count.index} Healthy"
  type    = "service check"
  message = "Sample API Service ${count.index} unhealthy! Check Railway."

  query = "\"http.can_connect\".over(\"instance:sample_api_${count.index}\",\"url:https://sample-api-${count.index}-dev.up.railway.app/health\").by(\"*\").last(1).pct_by_status()"

  monitor_thresholds {
    warning  = 3
    critical = 4
  }

  new_group_delay     = 120
  no_data_timeframe   = 5
  notify_no_data      = false
  notify_audit        = false
  timeout_h           = 24
  require_full_window = true
  renotify_interval   = 15
  include_tags        = false
}

