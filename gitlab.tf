### GitLab provider resources (groups, projects) ###

resource "gitlab_group" "devops_group" {
  count = var.enable_gitlab_resources ? 1 : 0

  path = "devops"
  name = "DevOps"
}

resource "gitlab_project" "devops" {
  count = var.enable_gitlab_resources ? 1 : 0

  name             = "devops"
  description      = "DevOps Project"
  visibility_level = "public"
  namespace_id     = gitlab_group.devops_group[0].id
}

resource "gitlab_project" "terraform" {
  count = var.enable_gitlab_resources ? 1 : 0

  name             = "terraform"
  description      = "Terraform Project"
  visibility_level = "public"
}
