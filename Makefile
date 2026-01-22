# Makefile for terraform-k8s-zcompute development workflow
# Run 'make help' for available targets

.PHONY: help init-hooks fmt lint validate docs security check-all clean

# Default target
help:
	@echo "Development targets:"
	@echo "  init-hooks  - Install pre-commit hooks and tflint plugins"
	@echo "  fmt         - Format Terraform files"
	@echo "  lint        - Run tflint"
	@echo "  validate    - Validate Terraform configuration"
	@echo "  docs        - Update README with terraform-docs"
	@echo "  security    - Run Checkov security scan"
	@echo "  check-all   - Run all checks (CI parity)"
	@echo "  clean       - Remove Terraform cache files"

# Initialize development environment
init-hooks:
	pre-commit install
	tflint --init
	@echo "Hooks installed. Run 'make check-all' to verify setup."

# Format Terraform files
fmt:
	terraform fmt -recursive

# Lint with tflint
lint:
	tflint --recursive --minimum-failure-severity=warning

# Validate Terraform configuration
validate:
	terraform init -backend=false -upgrade
	terraform validate

# Update README documentation
docs:
	terraform-docs .

# Run Checkov security scan
security:
	checkov -d . --config-file .checkov.yaml

# Run all checks (CI parity)
check-all: fmt validate lint docs security
	@echo ""
	@echo "All checks passed!"

# Clean Terraform cache
clean:
	rm -rf .terraform .terraform.lock.hcl
