# Cross-variable checks (require Terraform >= 1.5).

check "gitlab_docker_user_data_when_enabled" {
  assert {
    condition     = !var.gitlab_docker_enabled || length(trimspace(var.gitlab_docker_user_data)) > 0
    error_message = "gitlab_docker_user_data must be non-empty when gitlab_docker_enabled is true."
  }
}

check "runner_vm_name_distinct_from_gitlab" {
  assert {
    condition     = !var.enable_runner || var.gitlab_vm_name != var.runner_vm_name
    error_message = "gitlab_vm_name and runner_vm_name must differ when enable_runner is true."
  }
}

check "gitlab_runner_distinct_ipconfig" {
  assert {
    condition     = !var.enable_runner || var.gitlab_ipconfig0 != var.runner_ipconfig0
    error_message = "gitlab_ipconfig0 and runner_ipconfig0 must differ when enable_runner is true (assign distinct static IPs)."
  }
}
