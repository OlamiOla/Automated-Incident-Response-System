locals {
  project_name = "irs"
  environment  = get_env("TG_ENVIRONMENT", "dev")

  backend_vars = read_terragrunt_config(find_in_parent_folders("backend.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env/${local.environment}/env.hcl"))

  aws_region = local.region_vars.locals.aws_region
  account_id = local.account_vars.locals.account_id

  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terragrunt"
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend_generated.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = local.backend_vars.locals.state_bucket
    key          = "${local.environment}/${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.36"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = ${jsonencode(local.common_tags)}
  }
}
EOF
}

inputs = {
  project_name = local.project_name
  environment  = local.environment
  aws_region   = local.aws_region
  tags         = local.common_tags
}
