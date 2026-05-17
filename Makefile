# Run from repo root; Terraform lives in terraform/ (terraform init there first).
TF_DIR := terraform

.PHONY: fmt fmt-check validate check

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

fmt-check:
	cd $(TF_DIR) && terraform fmt -check $$(find . -name '*.tf')

validate: fmt-check
	cd $(TF_DIR) && terraform validate

check: validate
