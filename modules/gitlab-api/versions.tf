terraform {
  required_providers {
    gitlab = {
      source                = "gitlabhq/gitlab"
      version               = "18.11.0"
      configuration_aliases = [gitlab]
    }
  }
}
