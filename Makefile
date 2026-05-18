# Run from repo root; Terraform lives in terraform/ (terraform init there first).
TF_DIR := terraform

.PHONY: fmt fmt-check validate check plan plan-no-refresh state-rm-stale-gitlab

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

fmt-check:
	cd $(TF_DIR) && terraform fmt -check $$(find . -name '*.tf')

validate: fmt-check
	cd $(TF_DIR) && terraform validate

check: validate

# Skip state refresh (GitLab API / DNS) while bootstrapping or when old GitLab state exists but host is down.
plan-no-refresh:
	cd $(TF_DIR) && terraform plan -refresh=false

plan:
	cd $(TF_DIR) && terraform plan

# Remove GitLab API resources from state when enable_gitlab_resources=false but refresh still fails (host gone).
state-rm-stale-gitlab:
	cd $(TF_DIR) && terraform state list | grep -E '^(gitlab_|module\.gitlab_api)' | while read -r addr; do terraform state rm "$$addr"; done || true
