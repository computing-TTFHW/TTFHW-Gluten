# TTFHW-Gluten

鲲鹏适配的 Gluten 向量化加速库编译仓库。

## 概述

本仓库用于在 ARM 架构上编译 Gluten（向量化加速库），针对鲲鹏处理器进行优化适配。通过预构建的 Docker 镜像封装所有编译依赖，简化构建流程。

## 硬件要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| **架构** | ARM64 (aarch64) | 鲲鹏 920 |
| **CPU** | 4 核 | 8 核以上 |
| **内存** | 16 GB | 32 GB 以上 |
| **磁盘** | 50 GB 可用空间 | 100 GB SSD |
| **OS** | Linux (glibc 2.34+) | openEuler 22.03 SP3 |

> **注意**: 构建过程内存消耗较大，建议至少 16 GB 内存。内存不足可能导致编译失败。

## 软件依赖

以下依赖已预装在 Docker 镜像中，无需手动安装：

### 编译工具链
| 组件 | 版本 | 用途 |
|------|------|------|
| JDK | 8u462, 17, 21.0.9 (BiSheng) | Java 编译 |
| Maven | 3.9.9 | 项目构建 |
| CMake | 3.28.2 | C++ 构建系统 |
| LLVM | 15.0.4 | Clang 编译器 |
| Protobuf | 3.21.9 | 序列化库 |

### 基础依赖库
| 库 | 版本 | 用途 |
|----|------|------|
| zlib | 1.3.1 | 压缩库 |
| lz4 | 1.10.0 | 快速压缩 |
| zstd | 1.5.6 | 高压缩比 |
| snappy | 1.1.10 | 快速压缩 |
| jemalloc | 5.3.0 | 内存分配 |
| rocksdb | 8.11.4 | KV 存储 |
| re2 | 2024-07-02 | 正则表达式 |
| abseil-cpp | 20250127.0 | C++ 基础库 |
| libboundscheck | 1.1.16 | 边界检查 |

### 预装 Maven 依赖
| 依赖 | 版本 | 说明 |
|------|------|------|
| Arrow | 15.0.0-gluten | 列式存储 |
| Native Reader | 3.4.3-2.1.0 | 原生读取器 |

## 快速开始

### 方式一：GitHub Actions 自动构建（推荐）

1. Fork 本仓库
2. 进入 **Actions** 页面
3. 选择 **Build Gluten for Kunpeng (ARM)** workflow
4. 点击 **Run workflow**，选择分支：
   - `master`: 适配 Spark 3.4
   - `2026_330_poc`: 适配 Spark 3.5
5. 构建完成后下载 `gluten-artifacts-arm` 产物

### 方式二：本地 Docker 构建

#### 前置条件

- Docker 已安装并运行
- 有权限访问 `ghcr.io/computing-ttfhw/gluten-build:deps-latest` 镜像
- 本地磁盘空间 > 20 GB

#### 构建步骤

```bash
# 1. 克隆仓库
git clone https://github.com/computing-TTFHW/TTFHW-Gluten.git
cd TTFHW-Gluten

# 2. 登录 GitHub Container Registry（如需拉取私有镜像）
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 3. 拉取预构建镜像
docker pull ghcr.io/computing-ttfhw/gluten-build:deps-latest

# 4. 启动构建容器
docker run -d \
    --name gluten-builder \
    --user root \
    --workdir /opt \
    ghcr.io/computing-ttfhw/gluten-build:deps-latest \
    tail -f /dev/null

# 5. 复制构建脚本到容器
docker cp .ci/build/. gluten-builder:/opt/.ci/build/

# 6. 执行构建（master 分支适配 Spark 3.4）
docker exec -t \
    -e WORKSPACE=/opt \
    -e gluten_branch=master \
    gluten-builder \
    bash /opt/.ci/build/Gluten_compile.sh package

# 或者构建 2026_330_poc 分支（适配 Spark 3.5）
# docker exec -t \
#     -e WORKSPACE=/opt \
#     -e gluten_branch=2026_330_poc \
#     gluten-builder \
#     bash /opt/.ci/build/Gluten_compile.sh package

# 7. 提取构建产物
docker cp gluten-builder:/opt/toCMC/gluten.zip ./gluten.zip

# 8. 清理容器
docker stop gluten-builder && docker rm gluten-builder
```

#### 构建产物说明

解压 `gluten.zip` 后包含：

```
gluten.zip
├── software/
│   ├── BoostKit-omniruntime-gluten-2.0.0.zip  # Gluten 核心产物
│   └── Dependency_library_Gluten.zip           # 依赖库
└── inner/
    ├── repositories_info.json                  # 代码仓库信息
    └── Dependency_library_Gluten/              # 依赖库目录
```

`BoostKit-omniruntime-gluten-2.0.0.zip` 内包含：

| 文件 | 说明 |
|------|------|
| `libspark_columnar_plugin.so` | Gluten C++ 本地库 |
| `gluten-omni-bundle-spark-3.4_2.12-*.jar` | Gluten Java/Scala JAR |
| `libboundscheck.so` | 边界检查库 |
| `BoostKit-omniruntime-omnioperator-*.zip` | OmniOperator 运行时 |

## 构建脚本说明

### Gluten_compile.sh 用法

```bash
Gluten_compile.sh {compile|package}
```

| 命令 | 说明 |
|------|------|
| `compile` | 仅编译，不打包产物 |
| `package` | 编译并打包完整产物 |

### 构建流程

```
┌─────────────────────────────────────────────────────────────┐
│                    Gluten 构建流程                           │
├─────────────────────────────────────────────────────────────┤
│  1. init_environment     - 初始化构建环境                    │
│  2. clone_repos          - 克隆代码仓库 (Gluten, OmniOperator)│
│  3. deploy_omni_operator - 下载并部署 OmniOperator 运行时    │
│  4. compile_gluten       - 编译 Gluten C++ 和 Java 代码      │
│  5. package_artifacts    - 打包构建产物                      │
└─────────────────────────────────────────────────────────────┘
```

### 分支与 Spark 版本映射

| gluten_branch | Spark 版本 | 用途 |
|---------------|-----------|------|
| `master` | 3.4 | 生产环境 |
| `2026_330_poc` | 3.5 | POC 测试 |

## Docker 镜像构建

如需自定义镜像，可使用提供的 Dockerfile 构建：

### 镜像结构

```
Stage 1 (工具链镜像)
├── JDK 8/17/21
├── Maven 3.9.9
├── CMake 3.28.2
├── LLVM 15.0.4
├── Protobuf 3.21.9
└── fmt, folly

Stage 2 (依赖镜像) - 基于 Stage 1
├── 压缩库: zlib, lz4, zstd, snappy, jemalloc
├── 基础库: rocksdb, re2, abseil-cpp
├── libboundscheck
├── Arrow 15.0.0 Maven JAR
├── Native Reader JAR
└── Jenkins Agent
```

### 手动构建镜像

```bash
# 构建 Stage 1 (工具链镜像)
docker build \
    -f .ci/docker/openeuler_2203_sp3_01.Dockerfile \
    -t gluten-build:toolchain-custom \
    .ci/docker/

# 构建 Stage 2 (依赖镜像)
docker build \
    -f .ci/docker/openeuler_2203_sp3_02.Dockerfile \
    --build-arg BASE_IMAGE=gluten-build:toolchain-custom \
    -t gluten-build:deps-custom \
    .ci/docker/
```

## 配置说明

主要配置文件：`.ci/build/build_config.env`

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `OMNI_OPERATOR_VERSION` | OmniOperator 版本 | 2.1.0 |
| `ARROW_VERSION` | Arrow 版本 | 15.0.0 |
| `PRODUCT_VERSION` | 产物版本 | 2.0.0 |
| `COMPONENT_VERSION` | 组件版本 | 2.0.0 |
| `REPO_GLUTEN_URL` | Gluten 仓库地址 | gitcode.com/openeuler/Gluten.git |
| `REPO_OMNIOPERATOR_URL` | OmniOperator 仓库地址 | gitcode.com/openeuler/OmniOperator.git |

## 常见问题

### Q: 构建失败提示内存不足

确保系统有至少 16 GB 内存。可在 Docker 中调整内存限制：

```bash
docker run --memory=32g ...
```

### Q: 如何切换 Gluten 分支

通过环境变量 `gluten_branch` 指定：

```bash
docker exec -t -e gluten_branch=2026_330_poc ...
```

### Q: 镜像拉取失败

确认已登录 GitHub Container Registry：

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

## 参考文档

- [Gluten 官方文档](https://github.com/apache/incubator-gluten)
- [构建脚本参考](https://github.com/kerer-ai/operator)
- [OmniOperator 仓库](https://gitcode.com/openeuler/OmniOperator)

## 许可证

本项目遵循 Apache 2.0 许可证。