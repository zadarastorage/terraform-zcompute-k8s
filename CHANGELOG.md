# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.3.1...v2.0.0) (2025-09-16)

### ⚠ BREAKING CHANGES

* This discards the random_id cluster_token and now
requires the user to provide one. If cluster_token was not supplied
by the user previously, the current one should be extracted prior to
upgrade and configured in the user project.

### Features

* dont coalesce the cluster_token ([cf90efd](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/cf90efdd8a43ac68e77ffada4174a8d006a1ad30))

## [1.3.1](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.3.0...v1.3.1) (2025-07-24)

### Bug Fixes

* remove linux-modules-extra-* from auto-install, leave it to users for their specific usecases ([5d98a4f](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/5d98a4fb71e4bd9bfac06743a17e3edcfa35533d))

## [1.3.0](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.2.0...v1.3.0) (2025-06-30)


### Features

* add logic for automated cluster recovery from object storage on ([bda2534](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/bda2534e07f2e819d846d759b9b7c049891a68bb))
* enable overriding the endpoint url for customized sites ([356bbcd](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/356bbcd7d58862441647bf4c6bde591fe473bff2))

## [1.2.0](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.1.5...v1.2.0) (2025-06-30)


### Features

* enable etcd snapshot compression by default ([303375c](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/303375c4445449ee3c1530ba58d850e822ec1183))
* extend default etcd snapshot retention to 168. Should result in 28-day retention on object storage and 84-day retention locally ([887f253](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/887f2537722029d42592a25b9674ec33dbf7388c))
* preload matching linux kernel modules ([979d27c](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/979d27cc5b3db7ab5617a25450043c2d2e0818fe))

## [1.1.5](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.1.4...v1.1.5) (2025-06-17)


### Bug Fixes

* use systemd drop-in for udevd ([229d434](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/229d43423cea72a965311e630d07c7b53ff05ddd))

## [1.1.4](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.1.3...v1.1.4) (2025-06-16)


### Bug Fixes

* bump zadara_disk_mapper reference to enable virtio serial parsing ([ef1cd72](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/ef1cd72790d580f101bcbe7e623e4e97a2440c73))

## [1.1.3](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.1.2...v1.1.3) (2025-03-04)


### Bug Fixes

* configure kubelet to ignore vpc provided search domain ([a242944](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/a242944979fdb0cb8ce1d327c20c028c0028b722))

## [1.1.2](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.1.1...v1.1.2) (2025-01-30)


### Bug Fixes

* bump aws-ebs-csi-driver chart version to 2.39.3 ([6c63d50](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/6c63d500038fa0563c2bba8eef8400dfc9655a03))

## [1.1.1](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.1.0...v1.1.1) (2025-01-29)


### Bug Fixes

* re-enabling LBC management of backend security group rules ([1cf81c5](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/1cf81c5e67e84132e8074dd2722b732d54321591))

## [1.1.0](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.0.1...v1.1.0) (2025-01-24)


### Features

* construct etcd auto-restore logic ([0b64749](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/0b64749effcb231e0929ac2f51b983f5357125f3))

## [1.0.1](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v1.0.0...v1.0.1) (2025-01-21)


### Bug Fixes

* node_group_defaults.cloudinit_config should concat with node_groups.*.cloudinit_config, not replace ([c645342](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/c64534259abc8d51cbe81765b769ee22fac818d5))

## 1.0.0 (2025-01-17)


### Features

* initial commit ([cf832f0](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/cf832f07ab14fa69d9a8adfc8d12120f56e06597))

## 1.0.0 (2025-01-17)


### Features

* initial commit ([cf832f0](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/cf832f07ab14fa69d9a8adfc8d12120f56e06597))
