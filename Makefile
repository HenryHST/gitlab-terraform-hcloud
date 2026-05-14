.PHONY: fmt fmt-check validate check

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

validate: fmt-check
	terraform validate

# Alias: format check + validate (no network; run from repo root after terraform init)
check: validate
