terraform {
  required_providers {
    gitlab = {
      source                = "gitlabhq/gitlab"
      version               = "~> 18.11"
      configuration_aliases = [gitlab]
    }
  }
}
