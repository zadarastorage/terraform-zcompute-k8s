# etcd Backup and Restore

This module supports automatic etcd snapshots to S3-compatible object storage with auto-restore on cluster recreation.

## Configuration

Configure backups via the `etcd_backup` variable:

```hcl
module "k8s" {
  source = "github.com/your-org/terraform-zcompute-k8s"

  # ... other configuration ...

  etcd_backup = {
    s3             = "true"
    s3-endpoint    = "s3.us-east-1.amazonaws.com"
    s3-bucket      = "my-etcd-backups"
    s3-folder      = "cluster-name"
    s3-access-key  = var.backup_access_key
    s3-secret-key  = var.backup_secret_key
    s3-region      = "us-east-1"
    autorestore    = "true"  # Enable auto-restore on cluster recreate
  }
}
```

## Configuration Options

| Key | Description | Required |
|-----|-------------|----------|
| `s3` | Enable S3 backup (must be "true") | Yes |
| `s3-endpoint` | S3 API endpoint | Yes |
| `s3-bucket` | Bucket name for snapshots | Yes |
| `s3-folder` | Prefix/folder within bucket | No |
| `s3-access-key` | AWS access key ID | Yes |
| `s3-secret-key` | AWS secret access key | Yes |
| `s3-region` | S3 region | Yes |
| `s3-insecure` | Use HTTP instead of HTTPS | No (default: false) |
| `autorestore` | Auto-restore from latest snapshot | No (default: false) |
| `snapshot-schedule-cron` | Backup schedule (cron format) | No (default: @12h) |

## How Auto-Restore Works

When `autorestore = "true"` and the cluster is recreated:

1. The seed node (oldest control plane) detects no existing cluster
2. It queries S3 for the latest snapshot in the configured bucket/folder
3. If found, it restores from that snapshot before initializing
4. Other control plane nodes join the restored cluster
5. All etcd data (ConfigMaps, Secrets, etc.) is preserved

## Important Notes

- **Token consistency**: The same `cluster_token` must be used for backup and restore
- **Single bucket per cluster**: Each cluster should have its own folder or bucket
- **Snapshot retention**: Default is 168 snapshots (7 days at 1/hour)
- **Compression**: Snapshots are gzip compressed by default

## S3-Compatible Storage

Any S3-compatible storage works (AWS S3, MinIO, GarageHQ, etc.):

```hcl
# MinIO example
etcd_backup = {
  s3             = "true"
  s3-endpoint    = "minio.internal:9000"
  s3-bucket      = "etcd-backups"
  s3-region      = "us-east-1"  # Required but arbitrary for MinIO
  s3-insecure    = "true"       # If using HTTP
  s3-access-key  = var.minio_access_key
  s3-secret-key  = var.minio_secret_key
  autorestore    = "true"
}
```

## Manual Snapshot Commands

SSH to a control plane node to manage snapshots:

```bash
# Create on-demand snapshot
sudo k3s etcd-snapshot save --name manual-backup-$(date +%Y%m%d)

# List local snapshots
sudo k3s etcd-snapshot ls

# Delete old snapshot
sudo k3s etcd-snapshot delete <snapshot-name>
```

## Disaster Recovery

To restore a cluster from backup:

1. Ensure `etcd_backup` config matches the original cluster
2. Use the same `cluster_token` as the original cluster
3. Run `terraform destroy` then `terraform apply`
4. Auto-restore will find and apply the latest snapshot

For point-in-time recovery, set `cluster-reset-restore-path`:

```hcl
etcd_backup = {
  # ... s3 config ...
  cluster-reset-restore-path = "etcd-snapshot-2024-01-15T10-30-00Z"
}
```

## Variable Reference

The `etcd_backup` variable in the module's `variables.tf` is defined as:

```hcl
variable "etcd_backup" {
  description = "Configuration to automatically backup etcd to object storage"
  type        = map(string)
  default     = null
}
```

Configuration keys map directly to k3s `--etcd-*` flags with the `--etcd-` prefix removed. For example, the k3s flag `--etcd-s3-bucket=bucket` becomes `{ s3-bucket = "bucket" }` in this configuration.

See the [k3s etcd-snapshot documentation](https://docs.k3s.io/cli/etcd-snapshot#s3-compatible-object-store-support) for the full list of supported options.

## Troubleshooting

### Backup not appearing in S3

1. Verify credentials have write permissions to the bucket
2. Check k3s logs: `sudo journalctl -u k3s | grep -i etcd`
3. Verify endpoint connectivity from control plane node

### Auto-restore not triggering

1. Ensure `autorestore = "true"` is set
2. Verify the same `cluster_token` is used
3. Check k3s seed node logs during bootstrap
4. Verify S3 bucket has snapshots and credentials have read access

### Restore from specific snapshot

Use `cluster-reset-restore-path` to specify an exact snapshot name instead of latest:

```hcl
etcd_backup = {
  # ... s3 config ...
  cluster-reset-restore-path = "etcd-snapshot-YYYY-MM-DDTHH-MM-SSZ"
}
```
