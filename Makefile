# Makefile for terraform-k8s-zcompute development workflow
# Run 'make help' for available targets

.PHONY: help init-hooks fmt lint validate test test-verbose test-bats test-bats-debian test-all docs security check-all clean

# Default target
help:
	@echo "Development targets:"
	@echo "  init-hooks  - Install pre-commit hooks and tflint plugins"
	@echo "  fmt         - Format Terraform files"
	@echo "  lint        - Run tflint"
	@echo "  validate    - Validate Terraform configuration"
	@echo "  docs        - Update README with terraform-docs"
	@echo "  test        - Run Terraform tests"
	@echo "  test-verbose- Run Terraform tests with verbose output"
	@echo "  test-bats   - Run BATS shell script tests (Ubuntu)"
	@echo "  test-bats-debian - Run BATS tests (Debian)"
	@echo "  test-all    - Run all tests (Terraform + BATS)"
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

# Run Terraform tests
test:
	terraform test -test-directory=tests/unit

# Run Terraform tests with verbose output
test-verbose:
	terraform test -test-directory=tests/unit -verbose

# Run BATS shell script tests (Ubuntu)
test-bats:
	docker build -t bats-test -f tests/Dockerfile .
	docker run --rm -v "$$(pwd):/workspace" bats-test tests/bats/

# Run BATS shell script tests (Debian)
test-bats-debian:
	docker build -t bats-test-debian -f tests/Dockerfile --build-arg BASE_IMAGE=debian:12 .
	docker run --rm -v "$$(pwd):/workspace" bats-test-debian tests/bats/

# Run all tests (Terraform + BATS)
test-all: test test-bats

# Update README documentation
docs:
	terraform-docs .

# Run Checkov security scan
security:
	checkov -d . --config-file .checkov.yaml

# Run all checks (CI parity)
check-all: fmt validate test test-bats lint docs security
	@echo ""
	@echo "All checks passed!"

# Clean Terraform cache
clean:
	rm -rf .terraform .terraform.lock.hcl
