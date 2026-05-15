output "devops_group_id" {
  value = gitlab_group.devops_group.id
}

output "devops_project_id" {
  value = gitlab_project.devops.id
}

output "terraform_project_id" {
  value = gitlab_project.terraform.id
}

output "renovate_bot_user_id" {
  value = gitlab_user.renovate_bot.id
}
