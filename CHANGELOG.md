# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0](https://github.com/zadarastorage/terraform-zcompute-k8s/compare/v2.0.0...v2.1.0) (2026-01-28)


### Features

* **01-01:** convert to release-please from semantic-release ([7359827](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/735982780ae7d5cb9781cb55f432250375812fcf))
* **03-01:** add K8s baseline security configs ([cdafab0](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/cdafab0d40da85abe826e3b5fd5265ca4946d548))
* **03-01:** add security scanning workflow ([c021536](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/c021536474430bb90cbe8eb1fdbe4093cd08b963))
* **06-01:** add IAM test fixture ([f6d8b39](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/f6d8b39355a44b160d09da9952def4a4a5f0a5a3))
* **06-01:** add K8s test fixture ([1e5c950](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/1e5c9508b57aa9c9a368bf286d1975fb0310a94f))
* **06-01:** add VPC test fixture ([282b84d](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/282b84d10f45dbe0216846376f5101289042ba73))
* **06-02:** add integration test workflow with multi-fixture orchestration ([5b332c8](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/5b332c892946216f07c1b7b479b8283db3a96c7f))
* **06-03:** add cleanup workflow for orphaned K8s test resources ([3e53745](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/3e5374550778cec910abc4511ef0d4a359f7361c))
* add bastion host for CI cluster validation via SSH ([26af986](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/26af9861e89ae704540d898ad181de98b2d1434f))
* **ci:** add format, validate, and lint workflow ([a6256c0](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/a6256c03d83ecb7f6d9c96ec9d8cdb5f68aa4c93))
* require explicit default_instance_type instead of hardcoded z4.large ([f205c47](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/f205c47ab547bf146c094aa2975188b40e0d6832))
* scale to 3+1 topology with SSH key support ([d557299](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/d557299e62f3b338732e5615c6d7cd89551eeb7d))


### Bug Fixes

* **01-01:** use GITHUB_TOKEN with repository_dispatch for Release PR CI ([ee003e1](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/ee003e14202964f32fe1d04bf4a84868dd1a89d5))
* add STS endpoint to VPC fixture and show Trivy findings in logs ([f3df6c8](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/f3df6c8709703c75ab3d59086de4a43373fa9110))
* avoid zCompute volume tagging error in bastion fixture ([6c3c53a](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/6c3c53adbd4accfdfb12d4e0703e458bb997def0))
* **ci:** broaden path filter to trigger CI on all workflow changes ([72f2cc5](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/72f2cc53c66ce842b936f1f01e489dd9836fd818))
* **ci:** remove path filter from pull_request trigger ([f3b65ba](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/f3b65babb300ad6521e1ff54cb3cce4c96cc3d7d))
* **ci:** resolve release-please JSON parsing issue ([44a210f](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/44a210f284f7a7ea4fd8fc7ded02c9d95147edc2))
* enable NAT gateway for private subnet internet access ([bcc4478](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/bcc44786860c5c01f701d2af402876824253da47))
* extract real K3s kubeconfig from control node ([c2d53cc](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/c2d53ccd7e53237c9f27b07ff2e8217952790dac))
* pin bastion AWS provider to v3.35.0 for zCompute compatibility ([54fecf4](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/54fecf465002595cb9b17a0233a9f8878a78e756))
* remove default_tags from all fixtures, refine Trivy rationale ([8e8cbba](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/8e8cbbaa713369b4026f5cdb999271f69bba9eaf))
* remove tags from bastion SG and EIP for zCompute compatibility ([939c635](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/939c63502daf89f13e35b10f6f4879bd09e9020b))
* resolve CI failures in quality gates, integration tests, and security scans ([51269ee](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/51269ee3360ae6ad31215f727de5f6f6fa2e614b))
* suppress EBS encryption findings in Trivy ([dabe142](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/dabe1429db4dda4291a57f6d6da3b52091f7ff07))
* suppress Trivy AVD-AWS-0107 for bastion SSH ingress ([17b69fc](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/17b69fcfe291f1c2d51590d4ed110899c64ec3b9))


### Documentation

* **01-02:** add CONTRIBUTING.md with Conventional Commits section ([909c83c](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/909c83c8cb77264289dd925681167e754f85e620))
* **04-01:** add terraform-docs config and update README ([b7f98e7](https://github.com/zadarastorage/terraform-zcompute-k8s/commit/b7f98e7160729479245e924d742add4f232d9cf0))

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
