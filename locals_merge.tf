# Helm Chart Configuration Merge Logic
#
# Purpose: Merge user cluster_helm overrides with module defaults
#
# Behavior:
# - Chart-level merge: user charts are merged with default charts
# - Property-level merge: within each chart, properties are merged
# - Config-level merge: the "config" block is merged (not replaced)
# - User values take precedence over defaults at each level
# - null value for a chart disables it
# - enabled=false disables a chart
#
# Usage:
#   local.cluster_helm_merged - merged Helm configuration for cloud-init

locals {
  # Step 1: Get union of all chart names
  _helm_all_charts = distinct(concat(
    keys(local.cluster_helm_default),
    keys(var.cluster_helm)
  ))

  # Step 2: Pre-compute which charts have config maps in both sides
  _charts_with_both_configs = {
    for chart_name in local._helm_all_charts :
    chart_name => (
      contains(keys(local.cluster_helm_default), chart_name) &&
      contains(keys(var.cluster_helm), chart_name) &&
      try(local.cluster_helm_default[chart_name]["config"], null) != null &&
      try(var.cluster_helm[chart_name]["config"], null) != null &&
      can(keys(local.cluster_helm_default[chart_name]["config"])) &&
      can(keys(var.cluster_helm[chart_name]["config"]))
    )
  }

  # Step 3: Pre-compute merged configs for charts that have both
  _merged_configs = {
    for chart_name in local._helm_all_charts :
    chart_name => merge(
      try(local.cluster_helm_default[chart_name]["config"], {}),
      try(var.cluster_helm[chart_name]["config"], {})
    )
    if local._charts_with_both_configs[chart_name]
  }

  # Step 4: Build final merged charts
  cluster_helm_merged = {
    for chart_name in local._helm_all_charts :
    chart_name => merge(
      # Start with defaults
      try(local.cluster_helm_default[chart_name], {}),
      # Overlay user config
      try(var.cluster_helm[chart_name], {}),
      # Override config with merged version if applicable
      local._charts_with_both_configs[chart_name] ? {
        config = local._merged_configs[chart_name]
      } : {}
    )
    # Filter: exclude nulls and disabled charts
    if try(var.cluster_helm[chart_name], "keep") != null
    && try(
      merge(
        try(local.cluster_helm_default[chart_name], {}),
        try(var.cluster_helm[chart_name], {})
      ).enabled,
      true
    ) == true
  }
}
