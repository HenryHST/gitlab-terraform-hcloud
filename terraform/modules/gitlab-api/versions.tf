terraform {
  required_providers {
    gitlab = {
      source                = "gitlabhq/gitlab"
      version               = "~> 19.0"
      configuration_aliases = [gitlab]
    }
  }
}
