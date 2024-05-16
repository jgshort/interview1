provider "aws" {
  region = "us-east-1"
}

resource "aws_api_gateway_rest_api" "sample_rest_gateway" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "sample"
      version = "1.0"
    }
    paths = {
      "/dev" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "https://ip-ranges.amazonaws.com/ip-ranges.json"
          }
        }
      }
    }
  })

  description = "Sample API"
  name        = "sample"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "sample_rest_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.sample_rest_gateway.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.sample_rest_gateway.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "sample_reset_stage" {
  deployment_id = aws_api_gateway_deployment.sample_rest_gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.sample_rest_gateway.id
  stage_name    = "dev"
}

resource "aws_api_gateway_resource" "sample_health_resource" {
  rest_api_id = aws_api_gateway_rest_api.sample_rest_gateway.id
  parent_id   = aws_api_gateway_rest_api.sample_rest_gateway.root_resource_id
  path_part   = "health"
}

resource "aws_api_gateway_method" "sample_health_method" {
  rest_api_id   = aws_api_gateway_rest_api.sample_rest_gateway.id
  resource_id   = aws_api_gateway_resource.sample_health_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.sample_rest_gateway.id
  resource_id = aws_api_gateway_resource.sample_health_resource.id
  http_method = aws_api_gateway_method.sample_health_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration" "sample_health_integration" {
  rest_api_id = aws_api_gateway_rest_api.sample_rest_gateway.id
  resource_id = aws_api_gateway_resource.sample_health_resource.id
  http_method = aws_api_gateway_method.sample_health_method.http_method

  type                    = "HTTP"
  uri                     = "https://${var.load_balancer_name}/health"
  integration_http_method = "GET"
}

resource "aws_api_gateway_integration_response" "sample_health_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.sample_rest_gateway.id
  resource_id = aws_api_gateway_resource.sample_health_resource.id
  http_method = aws_api_gateway_method.sample_health_method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
}



resource "aws_cloudfront_distribution" "sample_api_distribution" {
  depends_on = [aws_api_gateway_rest_api.sample_rest_gateway]
  origin {
    domain_name = replace(aws_api_gateway_deployment.sample_rest_gateway_deployment.invoke_url, "/^https?://([^/]*).*/", "$1")
    origin_id   = "sample"
    origin_path = "/dev"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = "sample"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  ordered_cache_behavior {
    path_pattern     = "/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = "sample"

    default_ttl = 0
    min_ttl     = 0
    max_ttl     = 0

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  // NA and Europe
  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

