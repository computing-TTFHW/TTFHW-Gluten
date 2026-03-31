#!/bin/bash
set -ex

# ============================================================
# Gluten 构建主脚本（简化版）
#
# 已在镜像中预装的内容：
# - libboundscheck v1.1.16 (/usr/local/lib/*.so)
# - Native Reader JAR (两个版本)
# - Arrow 15.0.0 Maven JAR (~/.m2/repository/org/apache/)
# - protoc 符号链接 (/usr/local/bin/protoc)
# - 编译环境变量 (LD_LIBRARY_PATH, C_INCLUDE_PATH 等)
# ============================================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置文件
source "${SCRIPT_DIR}/build_config.env"

# 默认分支设置
: "${gluten_branch:=master}"

# -------------------- 初始化 --------------------
init_environment() {
    echo "=== 初始化构建环境 ==="

    export OMNI_HOME=$(pwd)
    mkdir -p ${OMNI_HOME}/lib/include

    agentpath="${WORKSPACE}/toCMC"
    rm -rf ${agentpath}
    mkdir -p ${agentpath}/software ${agentpath}/inner

    # 环境变量已在镜像中固化，无需重复设置
    # 仅添加运行时动态路径（OMNI_HOME）
    export LD_LIBRARY_PATH=${OMNI_HOME}/lib:$LD_LIBRARY_PATH
    export LIBRARY_PATH=${OMNI_HOME}/lib:$LIBRARY_PATH
    export C_INCLUDE_PATH=${OMNI_HOME}/lib/include:$C_INCLUDE_PATH
    export CPLUS_INCLUDE_PATH=${OMNI_HOME}/lib/include:$CPLUS_INCLUDE_PATH

    echo "=== 构建环境初始化完成 ==="
}

# -------------------- 代码仓库克隆 --------------------
clone_repos() {
    echo "=== 开始克隆代码仓库 ==="

    # Gluten
    echo "克隆 Gluten 仓库，分支: ${gluten_branch}"
    rm -rf ${WORKSPACE}/${REPO_GLUTEN_DIR}
    git clone -b ${gluten_branch} ${REPO_GLUTEN_URL} ${WORKSPACE}/${REPO_GLUTEN_DIR}

    # OmniOperator
    echo "克隆 OmniOperator 仓库"
    rm -rf ${WORKSPACE}/${REPO_OMNIOPERATOR_DIR}
    git clone ${REPO_OMNIOPERATOR_URL} ${WORKSPACE}/${REPO_OMNIOPERATOR_DIR}

    # 注意：libboundscheck 已在镜像中预装，无需克隆和编译

    echo "=== 代码仓库克隆完成 ==="
}

# -------------------- 部署 OmniOperator 运行时 --------------------
deploy_omni_operator() {
    echo "=== 部署 OmniOperator 运行时 ==="

    mkdir -p ${WORKSPACE}/output/operator_${OS_TYPE}

    # 根据分支选择下载路径
    local package_path
    if [ "${gluten_branch}" == "2026_330_poc" ]; then
        package_path=${OMNI_OPERATOR_PACKAGE_PATH_2026_330_POC}
    elif [ "${gluten_branch}" == "master" ]; then
        package_path=${OMNI_OPERATOR_PACKAGE_PATH_MASTER}
    else
        package_path="OmniOperator/${OmniOperatorJIT_branch}/Daily.26.0.0.B001"
    fi

    local zip_name=BoostKit-omniruntime-omnioperator-${OMNI_OPERATOR_VERSION}.zip
    wget "${OBS_BASE_URL}/${package_path}/${zip_name}"
    unzip -o ${zip_name}

    local tar_name=boostkit-omniop-operator-${OMNI_OPERATOR_VERSION}-aarch64-${OS_TYPE}.tar.gz
    tar -xf ${tar_name}

    local operator_dir=boostkit-omniop-operator-${OMNI_OPERATOR_VERSION}-aarch64
    cp -rf ${operator_dir} ${WORKSPACE}/output/operator_${OS_TYPE}

    # 安装 Maven 依赖
    mvn install:install-file \
        -DgroupId=${OMNI_UDF_GROUP_ID} \
        -DartifactId=${OMNI_UDF_ARTIFACT_ID} \
        -Dversion=${OMNI_OPERATOR_VERSION} \
        -Dclassifier=${OMNI_UDF_CLASSIFIER} \
        -Dpackaging=jar \
        -Dfile=${WORKSPACE}/output/operator_${OS_TYPE}/${operator_dir}/boostkit-omniop-udf-${OMNI_OPERATOR_VERSION}-aarch64.jar

    mvn install:install-file \
        -DgroupId=${OMNI_BINDINGS_GROUP_ID} \
        -DartifactId=${OMNI_BINDINGS_ARTIFACT_ID} \
        -Dversion=${OMNI_OPERATOR_VERSION} \
        -Dclassifier=${OMNI_BINDINGS_CLASSIFIER} \
        -Dpackaging=jar \
        -Dfile=${WORKSPACE}/output/operator_${OS_TYPE}/${operator_dir}/boostkit-omniop-bindings-${OMNI_OPERATOR_VERSION}-aarch64.jar

    # 复制头文件和库文件
    cp -rf ${WORKSPACE}/output/operator_${OS_TYPE}/${operator_dir}/include/* ${OMNI_HOME}/lib/include
    cp -rf ${WORKSPACE}/output/operator_${OS_TYPE}/${operator_dir}/*.so ${OMNI_HOME}/lib/

    echo "=== OmniOperator 运行时部署完成 ==="
}

# -------------------- 设置编译环境 --------------------
setup_compile_env() {
    # 环境变量已在镜像中固化，仅添加 OMNI_HOME 相关路径
    export LD_LIBRARY_PATH=${PROTOBUF_HOME}/lib:/opt/Gluten/lib:/opt/Gluten/lib64:${OMNI_HOME}/lib:$LD_LIBRARY_PATH
    export LIBRARY_PATH=${PROTOBUF_HOME}/lib:/opt/Gluten/lib:/opt/Gluten/lib64:${OMNI_HOME}/lib:$LIBRARY_PATH
    export C_INCLUDE_PATH=${LLVM_HOME}/include:${PROTOBUF_HOME}/include:/opt/Gluten/include:${OMNI_HOME}/lib/include:$C_INCLUDE_PATH
    export CPLUS_INCLUDE_PATH=${LLVM_HOME}/include:${PROTOBUF_HOME}/include:/opt/Gluten/include:${OMNI_HOME}/lib/include:$CPLUS_INCLUDE_PATH
}

# -------------------- 编译 Gluten --------------------
compile_gluten() {
    echo "=== 编译 Gluten ==="

    setup_compile_env

    pushd ${WORKSPACE}/${REPO_GLUTEN_DIR}
    ls -al
    chmod -R +x cpp-omni/build.sh
    bash cpp-omni/build.sh

    # 根据分支选择 Spark 版本
    local spark_version
    if [ "${gluten_branch}" == "2026_330_poc" ]; then
        spark_version=3.5
    else
        spark_version=3.4
    fi

    mvn clean package \
        ${MAVEN_PROFILE_OMNI} \
        -Pspark-${spark_version} \
        ${MAVEN_PROFILE_ICEBERG} \
        ${MAVEN_SKIP_TESTS} \
        ${MAVEN_SKIP_CHECKS}
    popd

    echo "=== Gluten 编译完成 ==="
}

# -------------------- 执行完整编译流程 --------------------
build_compile() {
    init_environment
    clone_repos
    # compile_libboundscheck - 已在镜像中预装，已移除
    # deploy_native_reader - 已在镜像中预装，已移除
    deploy_omni_operator
    # deploy_arrow - 已在镜像中预装，已移除
    compile_gluten
}

# -------------------- 生成版本信息 --------------------
generate_version_info() {
    touch version.txt
    echo "Product Name: Kunpeng BoostKit" >> version.txt
    echo "Product Version: ${PRODUCT_VERSION}" >> version.txt
    echo "Component Name: BoostKit-gluten" >> version.txt
    echo "Component Version: ${COMPONENT_VERSION}" >> version.txt
}

# -------------------- 打包产物 --------------------
package_artifacts() {
    echo "=== 打包构建产物 ==="

    pushd ${WORKSPACE}

    # 生成仓库信息
    python3 .ci/build/Retrieve_source_code.py .ci/build/code.xml ${WORKSPACE} repositories_info.json
    cp repositories_info.json ${agentpath}/inner

    # 收集产物文件
    mkdir -p ${WORKSPACE}/tmppackage

    cp ${WORKSPACE}/${REPO_GLUTEN_DIR}/cpp-omni/build/releases/libspark_columnar_plugin.so ${WORKSPACE}/tmppackage/
    cp ${WORKSPACE}/${REPO_GLUTEN_DIR}/package/target/gluten-omni-bundle-spark*_2.12-openEuler_22.03_aarch_64-1.3.0.jar ${WORKSPACE}/tmppackage/

    # libboundscheck 已在镜像中预装，从 /usr/local/lib 复制
    cp /usr/local/lib/libboundscheck*.so ${WORKSPACE}/tmppackage/

    cp ${WORKSPACE}/BoostKit-omniruntime-omnioperator-${OMNI_OPERATOR_VERSION}.zip ${WORKSPACE}/tmppackage/

    # 打包 Gluten 产物
    pushd ${WORKSPACE}/tmppackage
    generate_version_info
    zip -r BoostKit-omniruntime-gluten-${COMPONENT_VERSION}.zip ./*
    popd

    cp ${WORKSPACE}/tmppackage/BoostKit-omniruntime-gluten-${COMPONENT_VERSION}.zip ${agentpath}/software

    # 复制系统依赖库
    mkdir -p ${agentpath}/inner/Dependency_library_Gluten
    cp -rvf ${DEPENDENCIES_GlUTEN_PATH}/* ${agentpath}/inner/Dependency_library_Gluten
    cp -rvf ${DEPENDENCIES_ADAPTOR_PATH}/* ${agentpath}/inner/Dependency_library_Gluten

    # 打包依赖库
    pushd ${agentpath}/inner
    zip -r Dependency_library_Gluten.zip Dependency_library_Gluten
    cp Dependency_library_Gluten.zip ${agentpath}/software
    popd

    # 打包最终产物
    pushd ${WORKSPACE}/toCMC
    zip -r gluten.zip ./*
    popd

    # 生成元数据 JSON
    pushd ${agentpath}/software
    python3 ${WORKSPACE}/.ci/build/collect_software_info.py \
        --xml ${WORKSPACE}/.ci/build/code.xml \
        --workspace ${WORKSPACE} \
        BoostKit-omniruntime-gluten-${COMPONENT_VERSION}.zip
    python3 ${WORKSPACE}/.ci/build/collect_software_info.py \
        --xml ${WORKSPACE}/.ci/build/code.xml \
        --workspace ${WORKSPACE} \
        Dependency_library_Gluten.zip
    popd

    echo "=== 产物打包完成 ==="
}

# -------------------- 主入口 --------------------
main() {
    local command="$1"

    case ${command} in
        "compile")
            build_compile
            ;;
        "package")
            build_compile
            package_artifacts
            ;;
        *)
            echo "用法: $0 {compile|package}"
            exit 1
            ;;
    esac
}

main "$@"