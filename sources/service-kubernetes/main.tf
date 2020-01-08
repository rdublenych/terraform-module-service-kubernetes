terraform {
  required_version = ">= 0.12.0"
  required_providers {}
}

data "terraform_remote_state" "previous_state" {
  count = var.new ? 0 : 1

  backend = "s3"

  config = {
    bucket               = var.current_stack_state_configuration.bucket
    key                  = var.current_stack_state_configuration.key
    region               = var.current_stack_state_configuration.region
    workspace_key_prefix = var.current_stack_state_configuration.workspace_key_prefix
    acl                  = "private"
    encrypt              = true
  }
}

locals {
  active_environment_previous   = lookup(var.new ? {} : data.terraform_remote_state.previous_state[0].outputs[var.service_state_output_name], "active_environment", "blue")
  docker_image_active_previous  = lookup(var.new ? {} : data.terraform_remote_state.previous_state[0].outputs[var.service_state_output_name], "docker_image_active", "-")
  docker_image_passive_previous = lookup(var.new ? {} : data.terraform_remote_state.previous_state[0].outputs[var.service_state_output_name], "docker_image_passive", "-")

  active_environment = var.active_environment == "" ? local.active_environment_previous : var.active_environment
  swap_environments  = local.active_environment != local.active_environment_previous

  docker_image_active_calculated  = local.swap_environments == true ? local.docker_image_passive_previous : local.docker_image_active_previous
  docker_image_passive_calculated = local.swap_environments == true ? local.docker_image_active_previous : local.docker_image_passive_previous

  docker_image_active  = var.docker_image_active == "" ? local.docker_image_active_calculated : var.docker_image_active
  docker_image_passive = var.docker_image_passive == "" ? local.docker_image_passive_calculated : var.docker_image_passive
}

module "service-blue" {
  source = "../service-environment-kubernetes.tf"

  disabled = local.active_environment == "blue" ? local.docker_image_active == "-" : local.docker_image_passive == "-"

  desired_count               = var.desired_count
  docker_image                = local.active_environment == "blue" ? local.docker_image_active : local.docker_image_passive
  environment_variables       = var.environment_variables
  image_pull_secret_name      = var.image_pull_secret_name
  ingress_rules               = var.ingress_rules
  max_surge                   = var.max_surge
  max_unavailable             = var.max_unavailable
  port                        = var.port
  resource_requests           = var.resource_requests
  resource_limits             = var.resource_limits
  service_environment_name    = "${var.service_name}-blue"
  tls_certificate_issuer_name = var.tls_certificate_issuer_name
}

module "service-green" {
  source = "../service-environment-kubernetes.tf"

  disabled = local.active_environment == "green" ? local.docker_image_active == "-" : local.docker_image_passive == "-"

  desired_count               = var.desired_count
  docker_image                = local.active_environment == "blue" ? local.docker_image_active : local.docker_image_passive
  environment_variables       = var.environment_variables
  image_pull_secret_name      = var.image_pull_secret_name
  ingress_rules               = var.ingress_rules
  max_surge                   = var.max_surge
  max_unavailable             = var.max_unavailable
  port                        = var.port
  resource_requests           = var.resource_requests
  resource_limits             = var.resource_limits
  service_environment_name    = "${var.service_name}-green"
  tls_certificate_issuer_name = var.tls_certificate_issuer_name
}