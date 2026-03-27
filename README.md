# TTFHW-Gluten

鲲鹏适配的 Gluten 版本编译仓库。

## 概述

本仓库用于在 ARM 架构上编译 Gluten（向量化加速库），针对鲲鹏处理器进行优化适配。

## 构建

构建通过 GitHub Actions 自动执行，使用 `ubuntu-22.04-arm` runner 直接在 ARM 环境中构建，无需 QEMU 模拟。

### 手动触发构建

1. 进入 GitHub 仓库的 **Actions** 页面
2. 选择 **Build Gluten for Kunpeng (ARM)** workflow
3. 点击 **Run workflow**

### 自动构建

向 `main` 或 `master` 分支推送代码会自动触发构建。

## 构建产物

构建完成后，产物 `gluten.zip` 会作为 artifact 上传，可在 Actions 运行页面下载。

## 构建环境

- **Runner**: `ubuntu-22.04-arm` (原生 ARM 环境)
- **基础镜像**: `swr.cn-north-4.myhuaweicloud.com/cloud_boostkit/openeuler22.03_lts_sp3:arm64_003`
- **依赖仓库**:
  - Gluten: https://gitcode.com/openeuler/Gluten.git
  - OmniOperator: https://gitcode.com/openeuler/OmniOperator.git
  - libboundscheck: https://gitcode.com/openeuler/libboundscheck.git
  - BoostKit_CI: 华为云 DevCloud

## 参考文档

构建脚本参考自 [kerer-ai/operator](https://github.com/kerer-ai/operator)。