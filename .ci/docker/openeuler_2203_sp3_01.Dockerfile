# ============================================================
# openEuler 22.03 SP3 工具链基础镜像 (Stage 1)
# 包含: JDK21 (BiSheng), Maven, CMake, Protobuf, Lcov, LLVM-15
# ============================================================

ARG BASE_IMAGE=swr.cn-north-4.myhuaweicloud.com/cloud_boostkit/openeuler22.03_lts_sp3:latest
FROM ${BASE_IMAGE}

LABEL maintainer="kunpeng-team"
LABEL description="openEuler 22.03 SP3 toolchain base image"
LABEL stage="1"
LABEL version="1.0"

# ==================== 版本参数 ====================
ARG BISHENG_JDK_VERSION=21.0.9-b11
ARG MAVEN_VERSION=3.9.9
ARG CMAKE_VERSION=3.28.2
ARG PROTOBUF_VERSION=3.21.9
ARG LCOV_VERSION=1.16
ARG LLVM_VERSION=15.0.4

# ==================== 公共环境变量 ====================
ENV REPO_URL_CI=""
ENV REPO_URL_BMC=""
ENV INSTALL_LINUX_DIR="/tmp"

# ==================== 第一层：配置 yum repo ====================
COPY openEuler.repo /etc/yum.repos.d/openEuler.repo
RUN set -ex && \
    echo "140.82.112.4 github.com" >> /etc/hosts \
    && yum clean all \
    && yum makecache

# ==================== 第二层：安装系统依赖包 ====================
RUN set -ex && \
    yum install -y \
        sudo patch glibc zip unzip zlib wget curl tar \
        gcc java gcc-c++ make rpm git python3 cpio cmake \
        autoconf automake gettext-devel libtool meson \
        openssl-devel libuuid-devel \
        python3-pyelftools python-pyelftools \
        libaio-devel ncurses-devel \
        CUnit-devel libiscsi-devel json-c-devel libcmocka-devel \
        python3-pip python3-requests \
        byacc flex binutils-devel bison \
        boost boost-devel python3-devel \
        doxygen dos2unix \
        google-benchmark google-benchmark-devel \
        libasan glibc-devel libasan-static \
        jq bsdtar expect openssh vim strace \
        python-jenkins python-concurrent-log-handler \
        python3-gevent python3-marshmallow python3-pyyaml \
        python-pandas python-xlrd python-retrying \
        python-esdk-obs-python rpm-build \
    && yum clean all \
    && rm -rf /var/cache/yum

# ==================== 第三层：安装 BiSheng JDK ====================
RUN set -ex && \
    mkdir -p /opt/buildtools \
    && cd /opt/buildtools \
    && wget https://mirrors.huaweicloud.com/kunpeng/archive/compiler/bisheng_jdk/bisheng-jdk-${BISHENG_JDK_VERSION}-linux-aarch64.tar.gz \
    && tar -xf bisheng-jdk-${BISHENG_JDK_VERSION}-linux-aarch64.tar.gz \
    && rm -rf bisheng-jdk-${BISHENG_JDK_VERSION}-linux-aarch64.tar.gz \
    && sed -i '/JAVA_HOME/d' /etc/profile \
    && sed -i '/JRE_HOME/d' /etc/profile

# ==================== 第四层：安装 CMake ====================
RUN set -ex && \
    cd /opt/buildtools \
    && wget https://buildtools.obs.cn-north-4.myhuaweicloud.com/cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz \
    && tar -xf cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz \
    && rm -rf cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz \
    && rm -rf /usr/local/bin/cmake \
    && ln -sf cmake-${CMAKE_VERSION}-linux-aarch64/bin/cmake /usr/local/bin/cmake \
    && ln -sf cmake-${CMAKE_VERSION}-linux-aarch64/share/cmake-${CMAKE_VERSION%%.*}.28 /usr/local/share/

# ==================== 第五层：安装 Apache Maven ====================
RUN set -ex && \
    mkdir -p /opt/buildtools/apache-maven \
    && cd /opt/buildtools/apache-maven \
    && wget https://repo1.maven.org/maven2/org/apache/maven/apache-maven/${MAVEN_VERSION}/apache-maven-${MAVEN_VERSION}-bin.zip \
    && unzip apache-maven-${MAVEN_VERSION}-bin.zip \
    && rm -rf apache-maven-${MAVEN_VERSION}-bin.zip \
    && sed -i '/MAVEN_HOME/d' /etc/profile

# ==================== 第六层：安装 Protobuf ====================
RUN set -ex && \
    mkdir -p /opt/buildtools/Protobuf-${PROTOBUF_VERSION} \
    && cd /tmp \
    && git clone https://codehub.devcloud.cn-north-4.huaweicloud.com/b40eab964ee243e1a43336403eba828f/OpenSourceCenter/Gluten/protobuf.git \
    && cd protobuf \
    && git checkout v${PROTOBUF_VERSION} \
    && ./autogen.sh \
    && ./configure --enable-static=no --prefix=/opt/buildtools/Protobuf-${PROTOBUF_VERSION} \
    && make -j$(nproc) \
    && make install \
    && cd /tmp \
    && rm -rf protobuf

# ==================== 第七层：安装 Lcov ====================
RUN set -ex && \
    cd /opt/buildtools \
    && wget https://github.com/linux-test-project/lcov/releases/download/v${LCOV_VERSION}/lcov-${LCOV_VERSION}.tar.gz \
    && tar -xf lcov-${LCOV_VERSION}.tar.gz \
    && rm -rf lcov-${LCOV_VERSION}.tar.gz \
    && cd lcov-${LCOV_VERSION} \
    && make rpms \
    && rpm -ivh lcov-*.noarch.rpm \
    && cd /opt/buildtools \
    && rm -rf lcov-${LCOV_VERSION}

# ==================== 第八层：安装 LLVM ====================
RUN set -ex && \
    mkdir -p /opt/buildtools/LLVM-${LLVM_VERSION} \
    && export LLVM_install_dir=/opt/buildtools/LLVM-${LLVM_VERSION} \
    && cd /tmp \
    && wget https://buildtools.obs.cn-north-4.myhuaweicloud.com/llvm-project-llvmorg-${LLVM_VERSION}.tar.gz \
    && tar -zxf llvm-project-llvmorg-${LLVM_VERSION}.tar.gz \
    && rm -rf llvm-project-llvmorg-${LLVM_VERSION}.tar.gz \
    && mkdir -p llvm-project-llvmorg-${LLVM_VERSION}/build \
    && cd llvm-project-llvmorg-${LLVM_VERSION}/build \
    && cmake -G "Unix Makefiles" \
        -DLLVM-TARGETS_TO_BUILD="host;ARM;X86;AArch64;BPE" \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_BUILD_LLVM_DYLIB=true \
        -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_ENABLE_PROJECTS="clang;lld;libunwind;compiler-rt;lldb" \
        -DCMAKE_INSTALL_PREFIX=${LLVM_install_dir} \
        ../llvm \
    && make -j$(nproc) \
    && make install \
    && sed -i '/LLVM_HOME/d' /etc/profile \
    && cd /tmp \
    && rm -rf llvm-project-llvmorg-${LLVM_VERSION}

# ==================== 持久化环境变量 ====================
ENV JAVA_HOME=/opt/buildtools/bisheng-jdk-${BISHENG_JDK_VERSION%%-*}
ENV MAVEN_HOME=/opt/buildtools/apache-maven/apache-maven-${MAVEN_VERSION}
ENV LLVM_HOME=/opt/buildtools/LLVM-${LLVM_VERSION}
ENV CMAKE_ROOT=/opt/buildtools/cmake-${CMAKE_VERSION}-linux-aarch64/share
ENV PROTOBUF_HOME=/opt/buildtools/Protobuf-${PROTOBUF_VERSION}
ENV PATH=/opt/buildtools/cmake-${CMAKE_VERSION}-linux-aarch64/bin:/opt/buildtools/LLVM-${LLVM_VERSION}/bin:/opt/buildtools/apache-maven/apache-maven-${MAVEN_VERSION}/bin:/opt/buildtools/bisheng-jdk-${BISHENG_JDK_VERSION%%-*}/bin:/opt/buildtools/Protobuf-${PROTOBUF_VERSION}/bin:$PATH