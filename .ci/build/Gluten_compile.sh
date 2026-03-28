#!/bin/bash
set -ex

# ============================================================
# Gluten 构建主脚本
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

    # 设置构建工具环境变量
    export JAVA_HOME=${JAVA_HOME}
    export JRE_HOME=${JRE_HOME}
    export MAVEN_HOME=${MAVEN_HOME}
    export LLVM_HOME=${LLVM_HOME}
    export PROTOBUF_HOME=${PROTOBUF_HOME}
    export FMT_HOME=${FMT_HOME}
    export FOLLY_HOME=${FOLLY_HOME}

    # 设置 PATH
    export PATH=${CMAKE_HOME}/bin:${LLVM_HOME}/bin:${MAVEN_HOME}/bin:${JAVA_HOME}/bin:${JRE_HOME}/bin:${PROTOBUF_HOME}/bin:$PATH

    # 设置 CLASSPATH
    export CLASSPATH=${JAVA_HOME}/lib:${JRE_HOME}/lib:$CLASSPATH

    # Protobuf 配置
    export CMAKE_PREFIX_PATH=${PROTOBUF_HOME}
    export Protobuf_ROOT=${PROTOBUF_HOME}
    export Protobuf_PROTOC_EXECUTABLE=${PROTOBUF_HOME}/bin/protoc

    # 创建 protoc 符号链接
    sudo ln -sf ${PROTOBUF_HOME}/bin/protoc /usr/local/bin/
    protoc --version

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

    # libboundscheck
    echo "克隆 libboundscheck 仓库，版本: ${LIBBOUNDSCHECK_VERSION}"
    rm -rf ${WORKSPACE}/${REPO_LIBBOUNDSCHECK_DIR}
    git clone ${REPO_LIBBOUNDSCHECK_URL} ${WORKSPACE}/${REPO_LIBBOUNDSCHECK_DIR}
    pushd ${WORKSPACE}/${REPO_LIBBOUNDSCHECK_DIR}
    git checkout tags/${LIBBOUNDSCHECK_VERSION}
    popd

    echo "=== 代码仓库克隆完成 ==="
}

# -------------------- 编译 libboundscheck --------------------
compile_libboundscheck() {
    echo "=== 编译 libboundscheck ==="

    pushd ${WORKSPACE}/${REPO_LIBBOUNDSCHECK_DIR}
    make CC=gcc
    popd

    export LD_LIBRARY_PATH=${WORKSPACE}/${REPO_LIBBOUNDSCHECK_DIR}/lib:$LD_LIBRARY_PATH
    export LIBRARY_PATH=${WORKSPACE}/${REPO_LIBBOUNDSCHECK_DIR}/lib:$LIBRARY_PATH
    # 设置 WORKSPACE 作为包含路径，以便找到 libboundscheck/include/securec.h
    export C_INCLUDE_PATH=${WORKSPACE}:$C_INCLUDE_PATH
    export CPLUS_INCLUDE_PATH=${WORKSPACE}:$CPLUS_INCLUDE_PATH

    echo "=== libboundscheck 编译完成 ==="
}

# -------------------- 部署 Native Reader --------------------
deploy_native_reader() {
    echo "=== 部署 Native Reader ==="

    mkdir -p ${WORKSPACE}/${REPO_GLUTEN_DIR}/3rdparty
    pushd ${WORKSPACE}/${REPO_GLUTEN_DIR}/3rdparty

    if [ "${gluten_branch}" == "2026_330_poc" ]; then
        echo "gluten 2026_330_poc 分支已消减对 native-reader 的直接依赖"
    else
        local jar_name=${NATIVE_reader_ARTIFACT_ID}-3.4.3-${OMNI_OPERATOR_VERSION}.jar
        wget "${OBS_BASE_URL}/${NATIVE_reader_PACKAGE_PATH}/${jar_name}"

        mvn install:install-file \
            -DgroupId=${NATIVE_reader_GROUP_ID} \
            -DartifactId=${NATIVE_reader_ARTIFACT_ID} \
            -Dversion=3.4.3-${OMNI_OPERATOR_VERSION} \
            -Dpackaging=jar \
            -Dfile=${jar_name}
    fi
    popd

    echo "=== Native Reader 部署完成 ==="
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

# -------------------- 部署 Arrow 预编译库 --------------------
deploy_arrow() {
    echo "=== 部署 Arrow 预编译库 ==="

    pushd ~/.m2/repository/org/apache/
    local zip_name=arrow-${ARROW_VERSION}.zip
    wget "${OBS_BASE_URL}/${ARROW_PACKAGE_PATH}/${zip_name}"
    unzip -o ${zip_name}
    popd

    echo "=== Arrow 预编译库部署完成 ==="
}

# -------------------- 设置编译环境 --------------------
setup_compile_env() {
    export LD_LIBRARY_PATH=${PROTOBUF_HOME}/lib:/opt/Gluten/lib:/opt/Gluten/lib64:${OMNI_HOME}/lib:$LD_LIBRARY_PATH
    export LIBRARY_PATH=${PROTOBUF_HOME}/lib:/opt/Gluten/lib:/opt/Gluten/lib64:${OMNI_HOME}/lib:$LIBRARY_PATH
    export C_INCLUDE_PATH=/usr/local/include/orc:${LLVM_HOME}/include:${PROTOBUF_HOME}/include:/opt/Gluten/include:${OMNI_HOME}/lib/include:$C_INCLUDE_PATH
    export CPLUS_INCLUDE_PATH=/usr/local/include/orc:${LLVM_HOME}/include:${PROTOBUF_HOME}/include:/opt/Gluten/include:${OMNI_HOME}/lib/include:$CPLUS_INCLUDE_PATH
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
    compile_libboundscheck
    deploy_native_reader
    deploy_omni_operator
    deploy_arrow
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
    cp ${WORKSPACE}/${REPO_LIBBOUNDSCHECK_DIR}/lib/*.so ${WORKSPACE}/tmppackage/
    cp ${WORKSPACE}/BoostKit-omniruntime-omnioperator-${OMNI_OPERATOR_VERSION}.zip ${WORKSPACE}/tmppackage/

    # 复制 native-reader (如果存在)
    local native_reader_jar="${WORKSPACE}/${REPO_GLUTEN_DIR}/3rdparty/boostkit-omniop-native-reader-*-${OMNI_OPERATOR_VERSION}.jar"
    if [ -f "${native_reader_jar}" ]; then
        cp ${native_reader_jar} ${WORKSPACE}/tmppackage/
    fi

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
        "coverages_cpp")
            init_environment
            clone_repos
            ut_Gluten
            ;;
        *)
            echo "用法: $0 {compile|package|coverages_cpp}"
            exit 1
            ;;
    esac
}

main "$@"