# Merge Behavior Test Results

## Summary

| Metric | Value |
|--------|-------|
| Test Files | 5 |
| Total Tests | 19 |
| Passed | 19 |
| Failed | 0 |
| Execution Time | ~6 seconds |

## Before/After Comparison

### Before Fix (08-01b - Shallow Merge Bug)

The original shallow merge logic in `data_cloudinit.tf` used two-level merge:

```hcl
{ for k, v in merge(local.cluster_helm_default, var.cluster_helm) :
  k => merge(try(local.cluster_helm_default[k], {}), try(var.cluster_helm[k], {}))
  if v != null && try(v.enabled, true) == true }
```

**Bug Behavior:**
- When user provided `cluster_helm.cluster-autoscaler.config.awsRegion = "eu-west-1"`
- The entire `config` block was replaced with `{ awsRegion = "eu-west-1" }`
- Default config keys like `autoDiscovery`, `nodeSelector`, `tolerations` were LOST

**Test Results Before Fix:**
| Test | Result | Error |
|------|--------|-------|
| helm_override_loses_defaults | FAIL | autoDiscovery lost due to shallow merge |
| helm_override_nested_config_replaced | FAIL | sidecars lost due to shallow merge |

### After Fix (08-02 - Deep Merge Implementation)

The deep merge logic in `locals_merge.tf` performs config-level merging:

```hcl
# Pre-compute merged configs for charts that have both default and user configs
_merged_configs = {
  for chart_name in local._helm_all_charts :
  chart_name => merge(
    try(local.cluster_helm_default[chart_name]["config"], {}),
    try(var.cluster_helm[chart_name]["config"], {})
  )
  if local._charts_with_both_configs[chart_name]
}
```

**Fixed Behavior:**
- User's `config` keys are merged with default `config` keys
- Sibling config keys are preserved
- User values take precedence at leaf level

**Test Results After Fix:**
| Test | Result | Notes |
|------|--------|-------|
| helm_override_loses_defaults | PASS | autoDiscovery preserved alongside user's awsRegion |
| helm_override_nested_config_replaced | PASS | sidecars preserved alongside user's controller.region |

## Test Coverage by Category

### Bug Demonstration Tests (helm_shallow_merge.tftest.hcl)
Originally written to FAIL and demonstrate the bug, now PASS after fix:
- `helm_override_loses_defaults` - Verifies nested config siblings preserved
- `helm_override_nested_config_replaced` - Verifies deeply nested config preserved
- `helm_add_new_chart` - Adding new charts (always worked, positive control)

### Deep Merge Regression Tests (helm_deep_merge.tftest.hcl)
Would FAIL if shallow merge is reintroduced:
- `helm_partial_override_preserves_defaults` - Single config key override preserves chart defaults
- `helm_nested_override_preserves_siblings` - Nested override preserves sibling config sections
- `helm_multiple_level_override` - Chart-level and config-level overrides work together

### Edge Case Tests (helm_edge_cases.tftest.hcl)
Boundary condition coverage:
- `helm_null_in_user_config` - null value disables chart
- `helm_empty_config_override` - Empty config merges with defaults (not replace)
- `helm_enabled_false` - enabled=false excludes chart
- `helm_add_new_chart_with_config` - New charts don't affect defaults
- `helm_default_disabled_chart` - Default disabled charts stay disabled
- `helm_enable_default_disabled_chart` - User can enable disabled charts

### Replacement Behavior Tests (helm_replace.tftest.hcl)
Documents actual merge precedence:
- `helm_user_config_wins_at_leaf` - User values override defaults at same key
- `helm_chart_level_override` - Chart properties (order, namespace) can be overridden
- `helm_config_first_level_merge` - Config keys merge at first level
- `helm_multiple_charts_override` - Multiple charts can be overridden simultaneously

### Cloud-init Tests (cloudinit_concat.tftest.hcl)
Unrelated to merge bug, validates cloud-init concatenation:
- `cloudinit_user_parts_appended` - User parts added after defaults
- `cloudinit_order_respected` - Order attribute respected
- `cloudinit_multiple_user_parts` - Multiple user parts work

## Implementation Notes

### What Was Implemented
- Config-level deep merge (first level of config block)
- User values win at leaf level
- null value chart disabling
- enabled=false chart disabling
- Chart-level property override

### What Was NOT Implemented
- `_replace` sentinel key for explicit replacement
  - Documented in design but not implemented due to Terraform type system limitations
  - Users can achieve similar results by providing complete config blocks

## Regression Prevention

These tests serve as regression guards. If the deep merge logic is accidentally changed back to shallow merge:
- 6 tests in `helm_shallow_merge.tftest.hcl` and `helm_deep_merge.tftest.hcl` will FAIL
- Error messages clearly indicate "REGRESSION: ... lost due to shallow merge"

## Running Tests

```bash
cd tests/fixtures/merge
terraform test
```

Expected output: "Success! 19 passed, 0 failed."
