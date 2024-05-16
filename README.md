# Sample Project

> NOTE: This is based on a take home interview assessment utilizing Railway,
> Cloudflare, AWS, and Datadog; the architecture images and company details
> have been removed.

## ToC

1. [Design Objectives](#design-objectives)
    1. [The Sample API](#the-sample-api)
    1. [AWS Terraform State Management](#aws-terraform-state-management)
    1. [Datadog Agent](#datadog-agent)
    1. [CloudFlare Load Balancer](#cloudflare-load-balancer)
    1. [Chaos Monkey](#chaos-monkey)
1. [IaC](#iac)
    1. [Prerequisites](#prerequisites)
    1. [Terraform State](#terraform-state)
    1. [Resource Idempotency](#resource-idempotency)
1. [Deployment](#deployment)
1. [Load Balancing](#load-balancing)
1. [Observability](#observability)
1. [Interesting Finds](#interesting-finds)
    1. [Project Tokens](#project-tokens)
    1. [Railway Issues](#railway-issues)
1. [Bonus CDN](#bonus-cdn)

## Design Objectives

This project automates the deployment of the following services:

### The Sample API

This is a simple API deployed to Railway. It deploys a single project with four
distinct services:

1. Two `Sample API` services. These services are load balanced with Cloudflare.
   Additionally, these services are replicated within Railway. There are two
   replicas per service, and two origins (one per service) configured on the
   load balancer.
1. A Datadog agent to handle telemetry.
1. The Chaos Monkey. Every fifteen minutes, this service randomly selects one
   of the `Sample API` services and calls a `/boom` endpoint, which terminates
   the API. If fewer than two API services are healthy, the Chaos Monkey will
   restart the unavailable service.

### AWS Terraform State Management

Terraform state is stored in S3; Terraform locks are managed in DynamoDb.

### Datadog Agent

This service will push telemetry data to my personal Datadog account.

### CloudFlare Load Balancer

A Cloudflare Load Balancer is configured to randomly steer requests to one of
the two available `Sample API` services in Railway. The load balancer validates
available services by calling the `/health` endpoint in the `Sample API`. If
it's not healthy, traffic will redirect to the next available service.

> My Cloudflare account supports a maximum of two origins. I created one origin
> per `Sample API` service.

### Chaos Monkey

Every 15 minutes (the minimum cron service schedule supported by Railway), the
Chaos Monkey unleashes a reign of terror on the `Sample API`. It randomly
selects a healthy service and throws a banana at it, calling the `/boom` API,
which terminates the node instance within the service. It waits a beat, and
hits the `/boom` endpoint again, effectively killing all replicas within a
service.

The Chaos Monkey will restart unhealthy services on a subsequent run. If all
services are healthy, it will once again wildly throw a banana.

## IaC

I've included a Terraform solution to deploy the Railway services, Cloudflare
load balancer, and Datadog instrumentation.

Because the Terraform provider for Railway is somewhat incomplete, the GitHub
Action for the deployment workflow tries a little harder than it otherwise
would, as I needed to explicitly call the Railway GraphQL API for multiple
features, including secrets, domains, etc.

For simplicity, the CI/CD is maintained in a single workflow. In a production
setting, this would likely be split into multiple workflows.

### Prerequisites

The following secrets are managed in GitHub for this repository. They are
required to perform the work of the CI/CD and Terraform.

1. `RAILWAY_TOKEN` - My personal Railway API token.
1. `CLOUDFLARE_ZONE_ID` - My personal Cloudflare zone id.
1. `CLOUDFLARE_API_TOKEN` - ... and API token with permissions to my load balancers.
1. `CLOUDFLARE_ACCOUNT_ID` - ... and my Cloudflare account id.
1. `DD_API_KEY` - ... and my Datadog API key.
1. `DD_APP_KEY` - ... and my Datadog app key for Terraform.

Additionally, OIDC has been established between my personal AWS account and
GitHub for this repository. I'm happy to walk through the OIDC process if
requested.

### Terraform State

Terraform state is persisted to S3; Terraform locks are managed via DynamoDb.
There's a role and an attached policy to grant the GitHub Action permission to
save state to S3 and access the required locking tables in Dynamo. This is
handled through the aforementioned OIDC to AWS.

### Resource Idempotency

One issue I didn't handle is the creation of Railway service domains in an
idempotent manner. Since the Terraform provider doesn't include a provision for
domain names, the domain names are configured through the GraphQL interface.
Because I didn't add a step to check for the presence of an existing domain
name, the CI/CD workflow will create a new, randomly-assigned name provisioned
by Railway. Strictly, the GitHub Action should first check for the existence of
a domain on a service. Frankly, I ran out of time to handle this.

Likewise, I didn't add a provision to check for the existence of Railway
project tokens. Therefore, CI/CD project tokens are created ad infinitum.

Both of these issues are fixable; I was concerned about time.

## Deployment

Deployment is managed with GitHub Actions and triggered on every push to
`main`, with configuration managed under `.github/workflows/deploy.yml`.

Note: Cloudflare is managed as a separate step from the API deployment due to
the way Railway handles the creation of domain names on a service. These domain
names are required in order to correctly provision the load balancer pools.
Since the domain names must be created after the Terraform provider executes, I
needed to create a separate step specifically for Cloudflare.

> In the workflow's current state, a deployment will remove both services
> simultaneously. This isn't how it should work in a production environment,
> but it simplified the deployment.

## Load Balancing

Load balancing is performed by Cloudflare and configured via Terraform. There's
a single origin pool with a pair of origins corresponding to the Railway-hosted
services for the `Sample API` defined in Terraform.

The Cloudflare load balancer dashboard illustrates an example of the Chaos
Monkey in action. Here, the `railway-service-sample-api-1-dev-up-railway-app`
origin failed due to the Chaos Monkey, but continued to serve traffic to the
healthy service at origin `railway-service-sample-api-0-dev-up-railway-app`

Additionally, Cloudflare illustrates healthy, degraded, and critical
connectivity issues with its configured origins:

## Observability

Observability is handled with Datadog. Telemetry data is pushed to the Datadog
Agent service configured in Railway, which is subsequently sent to Datadog.

Additional metrics could be configured on the dashboard, or within the
Terraform deployment.

Further metrics are available through Cloudflare's Load Balancer Analytics
dashboard.

Monitors have been enabled to track the pair of Railway services for the
`Sample API` and the Cloudflare cluster.

