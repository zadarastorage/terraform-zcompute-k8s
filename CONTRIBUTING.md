# Contributing to terraform-zcompute-k8s

Thank you for your interest in contributing to the terraform-zcompute-k8s module! This document provides guidelines and instructions for contributing to the project.

## Development Setup

### Prerequisites

- Terraform >= 1.5.7
- Git
- Access to a zCompute environment (required for integration testing only)

### Clone and Validate

```bash
git clone https://github.com/zadarastorage/terraform-zcompute-k8s.git
cd terraform-zcompute-k8s

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Check formatting
terraform fmt -check -recursive
```

## Running Tests Locally

### Static Analysis (No Credentials Required)

These tests validate code quality and correctness without deploying infrastructure:

```bash
# Check Terraform formatting
terraform fmt -check -recursive

# Validate all configurations
terraform validate

# Run tflint (install from https://github.com/terraform-linters/tflint)
tflint --init
tflint --recursive --minimum-failure-severity=error
```

Static analysis runs automatically on all pull requests via GitHub Actions CI workflow.

### Integration Tests (Credentials Required)

Integration tests deploy actual infrastructure to zCompute to verify the module works correctly.

**Important:** K8s tests create full clusters including VPC and IAM resources. Due to autoscaler collision risks, only one K8s integration test can run at a time.

Integration tests will skip gracefully if zCompute credentials are not configured.

### Debugging Failed Tests

When integration tests fail, you can manually trigger the workflow with debug options:

1. Go to Actions > Integration Tests > Run workflow
2. Enable debug options:
   - **Skip destroy:** Keep all resources after test (useful for SSH debugging)
   - **Keep resources on failure:** Only keep resources if test fails

**Important:** Always clean up manually after debugging to avoid orphaned resources. Use the "Cleanup Test Resources" workflow or delete resources via zCompute console.

Resources are named with the pattern `test-k8s-v{version}-{run_id}` for easy identification.

### K8s Version Matrix

Integration tests validate the module against multiple Kubernetes versions to ensure compatibility across the supported version range.

**Currently Tested Versions:**

| Version | Release Date | Support Status |
|---------|--------------|----------------|
| 1.35    | [Latest]     | Current        |
| 1.34    | [Previous]   | Supported      |
| 1.33    | [Previous]   | Supported      |
| 1.32    | [Previous]   | LTS            |

**Policy:** Always test the latest K8s minor version plus the 3 previous minor versions. This aligns with the Kubernetes version skew policy and ensures users on supported versions can upgrade safely.

**Sequential Execution:** Tests run sequentially (`max-parallel: 1`) due to zCompute cluster-autoscaler collision risks. Each version deploys, validates, and destroys before the next version starts. This means the full test suite takes ~4x longer than a single-version test.

**Failure Behavior:** The test matrix uses `fail-fast: false` to continue testing remaining versions even if one version fails. This collects failure data for all versions, helping identify version-specific issues.

### Maintaining the Version Matrix

The version matrix should be updated quarterly when new Kubernetes minor versions are released.

**Quarterly Review Process:**

1. **Check for new K8s releases** at the start of each quarter (January, April, July, October)
2. **Update the matrix** in `.github/workflows/integration-test.yml`:
   - Add the new version at the top of the list
   - Remove the oldest version from the bottom
   - Keep exactly 4 versions (latest + 3 previous)
3. **Create a PR** with the version update
   - Title: `chore: update K8s test matrix to X.Y`
   - Run integration tests to validate all versions pass
4. **Update this documentation** with the new version table

**Example Update:**

When K8s 1.36 releases:
- Add `"1.36"` to the matrix
- Remove `"1.32"` from the matrix
- Update CONTRIBUTING.md table

```yaml
# Before
matrix:
  k8s_version: ["1.35", "1.34", "1.33", "1.32"]

# After
matrix:
  k8s_version: ["1.36", "1.35", "1.34", "1.33"]
```

**Version Format:** Use minor version only (e.g., `1.35` not `1.35.0`). The K8s module accepts minor version and automatically selects the latest patch.

## Commit Message Format

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automatic versioning and changelog generation. Every commit message must follow this format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | A new feature | Minor (0.x.0) |
| `fix` | A bug fix | Patch (0.0.x) |
| `docs` | Documentation only changes | None |
| `style` | Code style changes (formatting, semicolons) | None |
| `refactor` | Code change that neither fixes a bug nor adds a feature | None |
| `perf` | Performance improvement | Patch (0.0.x) |
| `test` | Adding or updating tests | None |
| `chore` | Maintenance tasks (deps, build) | None |

### Breaking Changes

For breaking changes, add `!` after the type or include `BREAKING CHANGE:` in the footer:

```
feat!: remove deprecated cluster_name variable

BREAKING CHANGE: The cluster_name variable has been removed. Use name instead.
```

Breaking changes trigger a major version bump (x.0.0).

### Examples

```bash
# Feature - triggers minor version bump
git commit -m "feat: add support for custom node pools"

# Bug fix - triggers patch version bump
git commit -m "fix: correct autoscaler configuration"

# Documentation - no version bump
git commit -m "docs: add examples for multi-node deployment"

# Breaking change - triggers major version bump
git commit -m "feat!: require Terraform 1.5+"
```

### Why This Matters

When you merge a PR to main, release-please analyzes your commit messages to:
1. Determine the next version number automatically
2. Generate CHANGELOG.md entries from your commit messages
3. Create a Release PR with the accumulated changes

Write clear, descriptive commit messages - they become your release notes!

## Pull Request Process

1. **Fork the repository** and create a feature branch from `main`

2. **Make your changes** following the code style guidelines

3. **Run static analysis locally** to catch issues early:
   ```bash
   terraform fmt -recursive
   terraform validate
   tflint --recursive
   ```

4. **Open a pull request** with a clear description of your changes
   - CI will automatically run static analysis
   - Integration tests will run if repository has credentials configured
   - For PRs from forks, integration tests will be skipped (this is expected)

5. **Address review feedback** from maintainers

6. **Maintainer approval and merge**
   - Maintainers will run integration tests before merging
   - Once approved, your contribution will be merged to `main`

## Code Style Guidelines

### Terraform Formatting

Always run `terraform fmt -recursive` before committing:

```bash
terraform fmt -recursive
```

This ensures consistent formatting across the codebase.

### Naming Conventions

- Use snake_case for all Terraform identifiers (variables, resources, outputs)
- Use descriptive names that clearly indicate purpose
- Follow existing patterns in the module

### Documentation

- Update README.md if adding user-facing features or changing behavior
- Include examples for new functionality
- Add inline comments for complex logic
- Update variable descriptions to be clear and helpful

## Reporting Issues

If you encounter a bug or have a feature request:

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with a clear title and description
3. **Include relevant details**:
   - Terraform version
   - Module version
   - zCompute platform version
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior

## Code of Conduct

This project follows the Contributor Covenant Code of Conduct. Please be respectful and professional in all interactions.

## Questions?

If you have questions about contributing, please open an issue or reach out to the maintainers.

Thank you for contributing to terraform-zcompute-k8s!
