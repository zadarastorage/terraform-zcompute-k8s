# Helm Chart Configuration Merge Logic
#
# Purpose: Merge user YAML configs with module defaults
#
# Sources (precedence order - later wins):
# 1. Module defaults (local.cluster_helm_default)
# 2. Inline YAML (local.cluster_helm_from_yaml via cluster_helm_yaml variable)
# 3. File-based YAML (local.cluster_helm_from_files via cluster_helm_values_dir variable)
#
# Behavior:
# - Chart-level merge: charts from all sources are merged (union of chart names)
# - Property-level merge: within each chart, properties are merged
# - Config-level merge: the "config" block is merged (not replaced)
# - Higher-precedence values win at leaf level
# - null value for a chart disables it
# - enabled=false in highest-precedence source disables the chart
#
# Usage:
#   local.cluster_helm_merged - merged Helm configuration for cloud-init

locals {
  # Step 1: Get union of all chart names from all three sources
  _helm_all_charts = distinct(concat(
    keys(local.cluster_helm_default),
    keys(local.cluster_helm_from_yaml),
    keys(local.cluster_helm_from_files)
  ))

  # Step 2: Pre-compute which charts have config maps in any source
  _charts_with_configs = {
    for chart_name in local._helm_all_charts :
    chart_name => {
      has_default = try(local.cluster_helm_default[chart_name]["config"], null) != null && can(keys(local.cluster_helm_default[chart_name]["config"]))
      has_yaml    = try(local.cluster_helm_from_yaml[chart_name]["config"], null) != null && can(keys(local.cluster_helm_from_yaml[chart_name]["config"]))
      has_files   = try(local.cluster_helm_from_files[chart_name]["config"], null) != null && can(keys(local.cluster_helm_from_files[chart_name]["config"]))
    }
  }

  # Step 3: Pre-compute merged configs for charts that have config in any source
  # Merge order: defaults < yaml < files
  _merged_configs = {
    for chart_name in local._helm_all_charts :
    chart_name => merge(
      try(local.cluster_helm_default[chart_name]["config"], {}),
      try(local.cluster_helm_from_yaml[chart_name]["config"], {}),
      try(local.cluster_helm_from_files[chart_name]["config"], {})
    )
    if anytrue([
      local._charts_with_configs[chart_name].has_default,
      local._charts_with_configs[chart_name].has_yaml,
      local._charts_with_configs[chart_name].has_files
    ])
  }

  # Step 4: Build final merged charts with precedence: defaults < yaml < files
  cluster_helm_merged = {
    for chart_name in local._helm_all_charts :
    chart_name => merge(
      # Layer 1: defaults (lowest priority)
      try(local.cluster_helm_default[chart_name], {}),
      # Layer 2: inline YAML
      try(local.cluster_helm_from_yaml[chart_name], {}),
      # Layer 3: file-based YAML (highest priority)
      try(local.cluster_helm_from_files[chart_name], {}),
      # Override config with merged version if any source has config
      contains(keys(local._merged_configs), chart_name) ? {
        config = local._merged_configs[chart_name]
      } : {}
    )
    # Filter: exclude nulls and disabled charts
    # A chart is excluded if ANY source sets it to null
    if try(local.cluster_helm_from_files[chart_name], "keep") != null
    && try(local.cluster_helm_from_yaml[chart_name], "keep") != null
    # Check enabled flag with precedence: files > yaml > default
    && try(
      coalesce(
        try(local.cluster_helm_from_files[chart_name].enabled, null),
        try(local.cluster_helm_from_yaml[chart_name].enabled, null),
        try(local.cluster_helm_default[chart_name].enabled, null),
        true
      ),
      true
    ) == true
  }
}
