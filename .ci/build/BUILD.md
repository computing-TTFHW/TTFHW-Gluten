# Gluten 构建系统文档

本文档详细说明 Gluten 项目的 CI 构建系统结构、流程和各文件作用。

## 目录结构

```
.ci/build/
├── build_config.env          # 构建配置文件（外部依赖集中管理）
├── Gluten_compile.sh         # 构建主脚本
├── code.xml                  # 代码仓库清单（用于生成元数据）
├── Retrieve_source_code.py   # 源码信息收集脚本
├── collect_software_info.py  # 软件包元数据生成脚本
└── BUILD.md                  # 本文档
```

## 文件说明

### 1. build_config.env

**作用：** 外部依赖配置文件，集中管理所有构建所需的外部资源。

**配置分类：**

| 分类 | 配置项 | 说明 |
|------|--------|------|
| **构建工具路径** | `JAVA_HOME` | JDK 8 安装路径 |
| | `MAVEN_HOME` | Maven 3.9.9 安装路径 |
| | `LLVM_HOME` | LLVM 15.0.4 安装路径 |
| | `CMAKE_HOME` | CMake 3.28.2 安装路径 |
| | `PROTOBUF_HOME` | Protobuf 3.21.9 安装路径 |
| **系统库路径** | `FMT_HOME` | fmt 库路径 |
| | `FOLLY_HOME` | folly 库路径 |
| **版本配置** | `OMNI_OPERATOR_VERSION` | OmniOperator 版本号 |
| | `ARROW_VERSION` | Apache Arrow 版本号 |
| | `LIBBOUNDSCHECK_VERSION` | libboundscheck 版本号 |
| | `PRODUCT_VERSION` | 产品版本号 |
| | `COMPONENT_VERSION` | 组件版本号 |
| **代码仓库** | `REPO_GLUTEN_URL/DIR` | Gluten 仓库地址和目录名 |
| | `REPO_OMNIOPERATOR_URL/DIR` | OmniOperator 仓库地址和目录名 |
| | `REPO_LIBBOUNDSCHECK_URL/DIR` | libboundscheck 仓库地址和目录名 |
| **预编译依赖包** | `OBS_BASE_URL` | 华为云 OBS 基础地址 |
| | `OMNI_OPERATOR_PACKAGE_PATH_*` | OmniOperator 运行时包路径 |
| | `NATIVE_reader_PACKAGE_PATH` | Native Reader 包路径 |
| | `ARROW_PACKAGE_PATH` | Arrow 预编译包路径 |
| **系统依赖库** | `DEPENDENCIES_GlUTEN_PATH` | Gluten 系统依赖库路径 |
| | `DEPENDENCIES_ADAPTOR_PATH` | Adaptor 系统依赖库路径 |
| **Maven 依赖** | `*_GROUP_ID/ARTIFACT_ID` | Maven 依赖坐标 |
| | `MAVEN_PROFILE_*` | Maven Profile 配置 |
| | `MAVEN_SKIP_*` | Maven 跳过检查参数 |

**使用方式：**
```bash
source build_config.env
```

---

### 2. Gluten_compile.sh

**作用：** 构建主脚本，执行完整的编译、打包流程。

**命令用法：**
```bash
./Gluten_compile.sh compile   # 仅编译
./Gluten_compile.sh package   # 编译并打包
./Gluten_compile.sh coverages_cpp  # 代码覆盖率测试
```

**环境变量：**
| 变量 | 说明 | 默认值 |
|------|------|--------|
| `WORKSPACE` | 工作空间根目录 | 必须设置 |
| `gluten_branch` | Gluten 代码分支 | `master` |

**函数列表：**

| 函数名 | 职责 | 执行内容 |
|--------|------|----------|
| `init_environment` | 初始化构建环境 | 加载配置、设置 PATH、创建目录结构 |
| `clone_repos` | 克隆代码仓库 | 克隆 Gluten、OmniOperator、libboundscheck |
| `compile_libboundscheck` | 编译边界检查库 | make 编译、设置库路径环境变量 |
| `deploy_native_reader` | 部署 Native Reader | 下载 JAR、安装到 Maven 本地仓库 |
| `deploy_omni_operator` | 部署 OmniOperator 运行时 | 下载预编译包、安装 Maven 依赖、复制头文件和库文件 |
| `deploy_arrow` | 部署 Arrow 预编译库 | 下载并解压到 Maven 本地仓库 |
| `setup_compile_env` | 设置编译环境变量 | 设置 LD_LIBRARY_PATH、C_INCLUDE_PATH 等 |
| `compile_gluten` | 编译 Gluten | 执行 C++ 编译和 Maven 打包 |
| `build_compile` | 执行完整编译流程 | 串联调用上述所有编译函数 |
| `generate_version_info` | 生成版本信息文件 | 创建 version.txt |
| `package_artifacts` | 打包构建产物 | 收集产物、生成元数据、打包 ZIP |
| `main` | 主入口 | 根据参数调用对应流程 |

---

### 3. code.xml

**作用：** 代码仓库清单，定义构建涉及的所有代码仓库。

**格式：**
```xml
<repositories>
    <repo url="仓库地址" dir="本地目录名"/>
</repositories>
```

**当前配置的仓库：**
| dir | url | 用途 |
|-----|-----|------|
| `gluten` | https://gitcode.com/openeuler/Gluten.git | 主项目代码 |
| `OmniOperatorJIT` | https://gitcode.com/openeuler/OmniOperator.git | JIT 运行时 |
| `libboundscheck` | https://gitcode.com/openeuler/libboundscheck.git | 安全边界检查库 |

> **注意：** 只保留实际克隆使用的仓库，移除了未使用的配置。

---

### 4. Retrieve_source_code.py

**作用：** 查找工作空间中的 Git 仓库，收集分支/tag、commit ID 等信息。

**命令用法：**
```bash
python3 Retrieve_source_code.py [xml_file] [workspace] [output_file]
```

**参数：**
| 参数 | 说明 | 默认值 |
|------|------|--------|
| `xml_file` | code.xml 配置文件路径 | `.ci/build/code.xml` |
| `workspace` | 工作空间目录 | 当前目录 |
| `output_file` | 输出 JSON 文件路径 | `repositories_info.json` |

**输出格式：**
```json
[
    {
        "repoUrl": "https://gitcode.com/openeuler/Gluten.git",
        "repoBranch": "master",
        "commitId": "abc123def456...",
        "dirName": "gluten"
    }
]
```

**特性：**
- 支持命令行参数，灵活指定输入输出
- 限制搜索深度（默认 4 级），提高效率
- 统一字段命名，与 `collect_software_info.py` 保持一致

---

### 5. collect_software_info.py

**作用：** 为构建产物生成完整的元数据 JSON 文件（SHA256、仓库信息、构建时间）。

**命令用法：**
```bash
python3 collect_software_info.py [options] <package_file>
```

**参数：**
| 参数 | 说明 | 默认值 |
|------|------|--------|
| `package_file` | 软件包文件路径（必需） | - |
| `--xml FILE` | code.xml 配置文件路径 | `.ci/build/code.xml` |
| `--workspace DIR` | 工作空间目录 | 当前目录 |
| `--output, -o FILE` | 输出 JSON 文件路径 | `<package_file>.json` |

**输出格式：**
```json
{
    "sha256Sum": "软件包SHA256摘要",
    "repoInfo": [
        {
            "repoUrl": "https://gitcode.com/openeuler/Gluten.git",
            "repoBranch": "master",
            "commitId": "abc123def456...",
            "dirName": "gluten"
        }
    ],
    "buildTime": "20260328153022"
}
```

## 构建流程

### 流程图

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Gluten 构建流程                               │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   开始       │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────────────────────────────┐
│ 加载配置文件 │ ──▶ │ build_config.env                     │
│              │     │ - 构建工具路径                        │
│              │     │ - 代码仓库地址                        │
│              │     │ - 预编译依赖包地址                    │
│              │     │ - 版本号                              │
└──────┬───────┘     └──────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│ 初始化环境   │
│              │
│ - 设置 PATH  │
│ - 创建目录   │
│ - 验证工具   │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────────────────────────────┐
│ 克隆代码仓库 │ ──▶ │ Gluten (指定分支)                     │
│              │     │ OmniOperator                          │
│              │     │ libboundscheck (指定版本)              │
└──────┬───────┘     └──────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│ 编译依赖库   │
│              │
│ - libboundscheck (本地编译)           │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────────────────────────────┐
│ 部署预编译包 │ ──▶ │ Native Reader JAR                    │
│              │     │ OmniOperator 运行时包                 │
│              │     │ Arrow 预编译库                        │
│              │     │                                      │
│              │     │ 来源: 华为云 OBS                      │
└──────┬───────┘     └──────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│ 编译 Gluten  │
│              │
│ - C++ 编译 (cpp-omni/build.sh)        │
│ - Maven 打包 (根据分支选择 Spark 版本) │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────────────────────────────┐
│ 打包产物     │ ──▶ │ libspark_columnar_plugin.so          │
│              │     │ gluten-omni-bundle-spark*.jar        │
│              │     │ libboundscheck/*.so                  │
│              │     │ OmniOperator ZIP                     │
│              │     │ Native Reader JAR (可选)              │
└──────┬───────┘     └──────────────────────────────────────┘
       │
       ▼
┌──────────────┐     ┌──────────────────────────────────────┐
│ 收集系统依赖 │ ──▶ │ /opt/Dependencies_openEuler22.03_Gluten │
│              │     │ /opt/Dependencies_openEuler22.03_Adaptor│
└──────┬───────┘     └──────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│ 生成元数据   │
│              │
│ - repositories_info.json              │
│ - 软件包 SHA256                        │
│ - 构建时间                             │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────────────────────────────┐
│ 最终打包     │ ──▶ │ BoostKit-omniruntime-gluten-2.0.0.zip │
│              │     │ Dependency_library_Gluten.zip         │
│              │     │ gluten.zip (总包)                     │
└──────┬───────┘     └──────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│   结束       │
└──────────────┘
```

### 产物输出路径

| 文件 | 路径 | 说明 |
|------|------|------|
| 总包 | `${WORKSPACE}/toCMC/gluten.zip` | 包含软件包和依赖库 |
| 软件包 | `${WORKSPACE}/toCMC/software/BoostKit-omniruntime-gluten-*.zip` | Gluten 编译产物 |
| 依赖库 | `${WORKSPACE}/toCMC/software/Dependency_library_Gluten.zip` | 系统依赖库 |
| 元数据 | `${WORKSPACE}/toCMC/software/*.json` | SHA256、仓库信息、构建时间 |

## 外部依赖清单

### 代码仓库

| 仓库 | 地址 | 分支/版本 | 用途 |
|------|------|-----------|------|
| Gluten | https://gitcode.com/openeuler/Gluten.git | 指定分支 | 主项目代码 |
| OmniOperator | https://gitcode.com/openeuler/OmniOperator.git | 默认分支 | JIT 运行时 |
| libboundscheck | https://gitcode.com/openeuler/libboundscheck.git | v1.1.16 | 安全边界检查库 |

### 预编译依赖包

| 包名 | 版本 | 来源路径 | 用途 |
|------|------|----------|------|
| OmniOperator 运行时 | 2.1.0 | `OBS_BASE_URL/OmniOperator/{branch}/Daily.26.0.0.B001/` | JIT 编译器、UDF、Bindings |
| Native Reader | 3.4.3-2.1.0 | `OBS_BASE_URL/omniop_native_reader/.../` | Native 数据读取器 |
| Arrow | 15.0.0 | `OBS_BASE_URL/Gluten/Compile_Rely/` | Apache Arrow 预编译库 |

### 构建工具

| 工具 | 版本 | 安装路径 |
|------|------|----------|
| JDK | 8u462-b08 | `/opt/buildtools/openjdk8/jdk8u462-b08` |
| Maven | 3.9.9 | `/opt/buildtools/apache-maven/apache-maven-3.9.9` |
| LLVM | 15.0.4 | `/opt/buildtools/LLVM-15.0.4` |
| CMake | 3.28.2 | `/opt/buildtools/cmake-3.28.2-linux-aarch64` |
| Protobuf | 3.21.9 | `/opt/buildtools/Protobuf-3.21.9` |

### 系统依赖库

| 路径 | 说明 |
|------|------|
| `/opt/Dependencies_openEuler22.03_Gluten` | Gluten 运行时依赖的系统库 |
| `/opt/Dependencies_openEuler22.03_Adaptor` | Adaptor 相关的系统库 |

## 版本升级指南

### 升级 OmniOperator 版本

修改 `build_config.env`：
```bash
OMNI_OPERATOR_VERSION=2.2.0  # 新版本号
```

同步更新 `OmniOperator_PACKAGE_PATH_*` 路径（如有变化）。

### 升级 Arrow 版本

修改 `build_config.env`：
```bash
ARROW_VERSION=16.0.0  # 新版本号
```

同步更新 `ARROW_PACKAGE_PATH` 路径（如有变化）。

### 升级构建工具

修改 `build_config.env` 中对应工具的路径：
```bash
JAVA_HOME=/opt/buildtools/openjdk11/jdk-11.0.x  # 升级 JDK
MAVEN_HOME=/opt/buildtools/apache-maven/apache-maven-3.9.x  # 升级 Maven
```

### 添加新的代码仓库

1. 在 `build_config.env` 添加：
```bash
REPO_NEWREPO_URL=https://xxx.git
REPO_NEWREPO_DIR=newrepo
```

2. 在 `code.xml` 添加：
```xml
<repo url="https://xxx.git" dir="newrepo"/>
```

3. 在 `Gluten_compile.sh` 的 `clone_repos()` 函数中添加克隆逻辑。

## CI Workflow 流程

参见 `.github/workflows/build_gluten_arm.yml`，流程如下：

```
Checkout → Check Docker → Cache → Load Docker Image → Start Container
    ↓
Copy build scripts → Execute build script → Copy artifact → Upload → Cleanup
```

关键步骤：
1. **Checkout**: 检出当前仓库（包含构建脚本）
2. **Copy build scripts**: 将 `.ci/build/` 复制到 Docker 容器
3. **Execute build script**: 执行 `Gluten_compile.sh package`
4. **Copy artifact**: 从容器拷贝 `gluten.zip`
5. **Upload artifacts**: 上传构建产物

## 常见问题

### Q: 如何切换 Gluten 分支？

通过环境变量 `gluten_branch` 指定：
```bash
gluten_branch=2026_330_poc ./Gluten_compile.sh package
```

或在 CI Workflow 中通过 `inputs.gluten_branch` 参数指定。

### Q: 构建产物在哪里？

构建完成后，产物位于：
- 容器内: `/opt/toCMC/gluten.zip`
- 本地（CI）: `${{ github.workspace }}/build-output/gluten.zip`

### Q: 如何验证构建环境？

检查构建工具版本：
```bash
protoc --version    # 应显示 libprotoc 3.21.9
java -version       # 应显示 1.8.x
mvn -version        # 应显示 3.9.9
```

### Q: 如何修改 Spark 版本？

Spark 版本由 `gluten_branch` 自动决定：
- `2026_330_poc` → Spark 3.5
- 其他分支 → Spark 3.4

如需手动指定，修改 `Gluten_compile.sh` 中的 `compile_gluten()` 函数。