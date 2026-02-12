# YAML parsing for Helm chart configuration
#
# This file provides two input paths for YAML-based Helm configuration:
# 1. Inline YAML via var.cluster_helm_yaml (supports multi-document)
# 2. Directory of per-chart files via var.cluster_helm_values_dir
#
# Outputs:
# - local.cluster_helm_from_yaml: Map of charts from inline YAML
# - local.cluster_helm_from_files: Map of charts from directory files
#
# These locals are consumed by locals_merge.tf.

#############################################################################
# Variable Injection
#
# Variables available for injection in YAML values:
#   $${cluster_name}  - Cluster name from var.cluster_name
#   $${endpoint}      - zCompute endpoint from var.zcompute_endpoint
#   $${pod_cidr}      - Pod CIDR range from var.pod_cidr
#   $${service_cidr}  - Service CIDR range from var.service_cidr
#
# Escape syntax: $$${...} produces literal $${...} (for Helm templates)
#
# Implementation: Chain of replace() calls
#   1. Escape $$${...} with placeholder
#   2. Replace each known $${var} with its value
#   3. Restore escaped sequences
#
# Note: Unknown $${...} patterns pass through unchanged (for Helm templates)
#############################################################################

locals {
  # Variables available for injection in YAML
  _injection_vars = {
    cluster_name = var.cluster_name
    endpoint     = var.zcompute_endpoint
    pod_cidr     = var.pod_cidr
    service_cidr = var.service_cidr
  }

  # Escape sequence placeholder - used to protect $$${...} sequences
  # This is restored to ${ at the end of substitution
  _escape_placeholder = "<<<ESCAPE>>>"

  # The literal string "$${" for restoration - must use heredoc to avoid template parsing
  _escape_restore = trimspace(<<-EOT
    $${
  EOT
  )
}

# Apply variable substitution to inline YAML
locals {
  # Step 1: Protect escaped sequences ($$${...} -> placeholder)
  # User writes $$${foo} to get literal $${foo} in output (for Helm templates)
  _yaml_escaped = var.cluster_helm_yaml != null ? replace(
    var.cluster_helm_yaml,
    "$$$${",
    local._escape_placeholder
  ) : null

  # Step 2: Substitute known variables (order doesn't matter)
  # Search for literal $${cluster_name} etc.
  _yaml_sub_1 = local._yaml_escaped != null ? replace(
    local._yaml_escaped, "$${cluster_name}", local._injection_vars.cluster_name
  ) : null

  _yaml_sub_2 = local._yaml_sub_1 != null ? replace(
    local._yaml_sub_1, "$${endpoint}", local._injection_vars.endpoint
  ) : null

  _yaml_sub_3 = local._yaml_sub_2 != null ? replace(
    local._yaml_sub_2, "$${pod_cidr}", local._injection_vars.pod_cidr
  ) : null

  _yaml_sub_4 = local._yaml_sub_3 != null ? replace(
    local._yaml_sub_3, "$${service_cidr}", local._injection_vars.service_cidr
  ) : null

  # Step 3: Restore escaped sequences (placeholder -> $${)
  _yaml_substituted = local._yaml_sub_4 != null ? replace(
    local._yaml_sub_4, local._escape_placeholder, local._escape_restore
  ) : null
}

locals {
  #############################################################################
  # Multi-Document YAML Parsing (Pattern from GitHub Issue #29729)
  #
  # Terraform's yamldecode() does not support multi-document YAML (--- separators).
  # This workaround splits the input on document separators and decodes each
  # document individually, then merges the results.
  #############################################################################

  # Use substituted YAML for parsing (variable injection applied above)
  _raw_yaml = local._yaml_substituted != null ? local._yaml_substituted : ""

  # Normalize YAML input:
  # - Add boundary newlines to ensure split works at document edges
  # - Strip trailing whitespace and comments from --- lines
  # The regex (?m) enables multiline mode, ^---[[:blank:]]*(#.*)?$ matches
  # document separators with optional trailing whitespace and comments
  _yaml_normalized = "\n${replace(local._raw_yaml, "/(?m)^---[[:blank:]]*(#.*)?$/", "---")}\n"

  # Split on document separator (\n---\n) and decode each non-empty document
  # The filter removes:
  # - Empty documents (just whitespace)
  # - Comment-only documents (lines starting with #)
  _yaml_documents = [
    for doc in split("\n---\n", local._yaml_normalized) :
    yamldecode(doc)
    if trimspace(replace(doc, "/(?m)(^[[:blank:]]*(#.*)?$)+/", "")) != ""
  ]

  # Merge all documents into a single map
  # Later documents override earlier ones (chart names are top-level keys)
  # Returns empty map if no valid documents found
  # Note: We always return a map type using try/default pattern to avoid
  # Terraform type inconsistency errors when YAML content varies
  cluster_helm_from_yaml = try(merge(local._yaml_documents...), {})

  #############################################################################
  # Directory-Based File Loading
  #
  # Enumerates YAML files in the specified directory and parses each one.
  # The filename (without extension) becomes the release/chart name.
  # Variable substitution is applied to file content before parsing.
  #############################################################################

  # Enumerate YAML files in directory (flat, no subdirectories)
  # Both .yaml and .yml extensions are supported
  # Note: fileset will error if directory doesn't exist - this is documented
  # in the variable description as expected behavior
  _helm_files = var.cluster_helm_values_dir != null ? fileset(var.cluster_helm_values_dir, "*.{yaml,yml}") : toset([])

  # Read raw file content (before substitution)
  _files_raw_content = {
    for f in local._helm_files :
    trimsuffix(trimsuffix(f, ".yaml"), ".yml") => file("${var.cluster_helm_values_dir}/${f}")
  }

  # Apply variable substitution to each file and parse
  # Same substitution chain as inline YAML:
  # 1. Escape $$${...} with placeholder
  # 2. Replace known variables
  # 3. Restore escaped sequences
  # 4. yamldecode the result
  cluster_helm_from_files = {
    for name, content in local._files_raw_content :
    name => try(
      yamldecode(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(content, "$$$${", local._escape_placeholder),
                  "$${cluster_name}", local._injection_vars.cluster_name
                ),
                "$${endpoint}", local._injection_vars.endpoint
              ),
              "$${pod_cidr}", local._injection_vars.pod_cidr
            ),
            "$${service_cidr}", local._injection_vars.service_cidr
          ),
          local._escape_placeholder, local._escape_restore
        )
      ),
      {} # Empty file fallback - return empty object instead of error
    )
  }
}
