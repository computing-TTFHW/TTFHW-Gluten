# ============================================================
# openEuler 22.03 SP3 构建基础镜像 (Stage 1)
# 输出镜像: ghcr.io/{owner}/openeuler-build:26330_01
# 包含:
#   - 编译工具链: JDK8, JDK21, Maven, CMake, LLVM-15, Protobuf
#   - 基础库: fmt, folly
#   - 开发工具: Lcov, Python包
#   - 系统依赖: 所有构建所需的系统包
# ============================================================

# 基础镜像使用华为云 SWR 的 openEuler 官方镜像
ARG BASE_IMAGE=swr.cn-north-4.myhuaweicloud.com/cloud_boostkit/openeuler22.03_lts_sp3:latest
FROM ${BASE_IMAGE}

LABEL maintainer="kunpeng-team"
LABEL description="openEuler 22.03 SP3 build base image with toolchain and libraries"
LABEL stage="1"
LABEL tag="26330_01"

# ==================== 版本参数 ====================
# JDK
ARG JDK8_VERSION=462
ARG JDK8_BUILD=b08
ARG BISHENG_JDK_VERSION=21.0.9-b11
ARG JDK17_VERSION=17

# 构建工具
ARG MAVEN_VERSION=3.9.9
ARG CMAKE_VERSION=3.28.2
ARG PROTOBUF_VERSION=3.21.9
ARG LLVM_VERSION=15.0.4
ARG LCOV_VERSION=1.16

# 基础库
ARG FMT_VERSION=10.1.1
ARG FOLLY_VERSION=v2024.07.01.00

# ==================== 公共环境变量 ====================
ENV REPO_URL_CI=""
ENV REPO_URL_BMC=""
ENV INSTALL_LINUX_DIR="/tmp"
ENV LANG=C.utf8
ENV LC_ALL=C.utf8
ENV LANGUAGE=C.utf8

# ==================== 第一层：配置 yum repo ====================
COPY openEuler.repo /etc/yum.repos.d/openEuler.repo
RUN set -ex && \
    yum clean all \
    && yum makecache

# ==================== 第二层：安装系统依赖包 ====================
# 合并所有阶段需要的系统包，一次性安装
RUN set -ex && \
    yum install -y \
        # 基础工具
        sudo patch glibc zip unzip zlib wget curl tar \
        gcc java gcc-c++ make rpm git python3 cpio \
        # 构建工具
        autoconf automake gettext-devel libtool meson cmake \
        byacc flex binutils-devel bison \
        # 开发库
        openssl-devel libuuid-devel libaio-devel ncurses-devel \
        python3-pyelftools python-pyelftools \
        CUnit-devel libiscsi-devel json-c-devel libcmocka-devel \
        boost boost-devel python3-devel \
        # folly 依赖
        double-conversion-devel libevent-devel glog-devel \
        # 开发工具
        doxygen dos2unix ccache ninja-build patchelf \
        google-benchmark google-benchmark-devel \
        libasan glibc-devel libasan-static \
        # 调试和监控
        perf binutils tree strace \
        # Python 包管理
        python3-pip python3-requests \
        python-jenkins python-concurrent-log-handler \
        python3-gevent python3-marshmallow python3-pyyaml \
        python-pandas python-xlrd python-retrying \
        python-esdk-obs-python \
        # 其他工具
        jq bsdtar expect openssh vim rpm-build \
        texinfo \
    && dnf reinstall -y --allowerasing glibc-common \
    && locale \
    && yum clean all \
    && rm -rf /var/cache/yum

# ==================== 第三层：安装 Python 包 ====================
RUN set -ex && \
    pip3 install \
        pandas \
        tqdm \
        openpyxl \
        pyinstaller \
        fastcov \
    -i http://mirrors.aliyun.com/pypi/simple/ \
    --trusted-host mirrors.aliyun.com

# ==================== 第四层：安装 JDK8 ====================
RUN set -ex && \
    mkdir -p /opt/buildtools/openjdk8 \
    && cd /opt/buildtools/openjdk8 \
    && wget https://buildtools.obs.cn-north-4.myhuaweicloud.com/OpenJDK8U-jdk_aarch64_linux_hotspot_8u${JDK8_VERSION}${JDK8_BUILD}.tar.gz \
    && tar -xf OpenJDK8U-jdk_aarch64_linux_hotspot_8u${JDK8_VERSION}${JDK8_BUILD}.tar.gz \
    && rm -rf OpenJDK8U-jdk_aarch64_linux_hotspot_8u${JDK8_VERSION}${JDK8_BUILD}.tar.gz

# ==================== 第五层：安装 BiSheng JDK 21 ====================
RUN set -ex && \
    mkdir -p /opt/buildtools \
    && cd /opt/buildtools \
    && wget https://mirrors.huaweicloud.com/kunpeng/archive/compiler/bisheng_jdk/bisheng-jdk-${BISHENG_JDK_VERSION}-linux-aarch64.tar.gz \
    && tar -xf bisheng-jdk-${BISHENG_JDK_VERSION}-linux-aarch64.tar.gz \
    && rm -rf bisheng-jdk-${BISHENG_JDK_VERSION}-linux-aarch64.tar.gz \
    && sed -i '/JAVA_HOME/d' /etc/profile \
    && sed -i '/JRE_HOME/d' /etc/profile

# ==================== 第六层：安装 JDK17 (Jenkins Agent 需要) ====================
RUN set -ex && \
    wget -q https://mirrors.huaweicloud.com/openjdk/${JDK17_VERSION}/openjdk-${JDK17_VERSION}_linux-aarch64_bin.tar.gz -O /tmp/jdk17.tar.gz \
    && mkdir -p /usr/local \
    && tar -xzf /tmp/jdk17.tar.gz -C /usr/local \
    && rm /tmp/jdk17.tar.gz \
    && mv /usr/local/jdk-${JDK17_VERSION} /usr/local/openjdk-${JDK17_VERSION} \
    && chmod a+rx /usr/local/openjdk-${JDK17_VERSION} \
    && ln -sf /usr/local/openjdk-${JDK17_VERSION}/bin/java /usr/local/bin/java

# ==================== 第七层：安装 CMake ====================
RUN set -ex && \
    mkdir -p /opt/buildtools \
    && cd /opt/buildtools \
    && wget https://buildtools.obs.cn-north-4.myhuaweicloud.com/cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz \
    && tar -xf cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz \
    && rm -rf cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz \
    && rm -rf /usr/local/bin/cmake \
    && ln -sf cmake-${CMAKE_VERSION}-linux-aarch64/bin/cmake /usr/local/bin/cmake \
    && ln -sf cmake-${CMAKE_VERSION}-linux-aarch64/share/cmake-${CMAKE_VERSION%%.*}.28 /usr/local/share/

# ==================== 第八层：安装 Apache Maven ====================
RUN set -ex && \
    mkdir -p /opt/buildtools/apache-maven \
    && cd /opt/buildtools/apache-maven \
    && wget https://repo1.maven.org/maven2/org/apache/maven/apache-maven/${MAVEN_VERSION}/apache-maven-${MAVEN_VERSION}-bin.zip \
    && unzip apache-maven-${MAVEN_VERSION}-bin.zip \
    && rm -rf apache-maven-${MAVEN_VERSION}-bin.zip \
    && sed -i '/MAVEN_HOME/d' /etc/profile

# ==================== 第九层：安装 Protobuf ====================
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

# ==================== 第十层：安装 Lcov ====================
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

# ==================== 第十一层：安装 LLVM ====================
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

# ==================== 第十二层：安装 fmt 库 ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/fmt.git \
    && cd fmt \
    && git checkout tags/${FMT_VERSION} \
    && mkdir -p build \
    && cd build \
    && cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DFMT_TEST=OFF \
        -DFMT_DOC=OFF \
        -DFMT_INSTALL=ON \
        -DBUILD_SHARED_LIBS=ON \
    && make -j$(nproc) \
    && make install \
    && cd /tmp \
    && rm -rf fmt

# ==================== 第十三层：安装 folly 库 ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/folly.git \
    && cd folly \
    && git checkout tags/${FOLLY_VERSION} \
    && mkdir -p build \
    && cd build \
    && cmake .. \
        -DFOLLY_HAVE_INT128_T=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    && make -j$(nproc) \
    && make install \
    && cd /tmp \
    && rm -rf folly

# ==================== 持久化环境变量 ====================
# 默认使用 JDK21
ENV JAVA_HOME=/opt/buildtools/bisheng-jdk-${BISHENG_JDK_VERSION%%-*}
ENV JDK8_HOME=/opt/buildtools/openjdk8/jdk8u${JDK8_VERSION}-${JDK8_BUILD}
ENV JDK17_HOME=/usr/local/openjdk-${JDK17_VERSION}
ENV MAVEN_HOME=/opt/buildtools/apache-maven/apache-maven-${MAVEN_VERSION}
ENV LLVM_HOME=/opt/buildtools/LLVM-${LLVM_VERSION}
ENV CMAKE_ROOT=/opt/buildtools/cmake-${CMAKE_VERSION}-linux-aarch64/share
ENV PROTOBUF_HOME=/opt/buildtools/Protobuf-${PROTOBUF_VERSION}
ENV PATH=/opt/buildtools/cmake-${CMAKE_VERSION}-linux-aarch64/bin:/opt/buildtools/LLVM-${LLVM_VERSION}/bin:/opt/buildtools/apache-maven/apache-maven-${MAVEN_VERSION}/bin:/opt/buildtools/bisheng-jdk-${BISHENG_JDK_VERSION%%-*}/bin:/opt/buildtools/Protobuf-${PROTOBUF_VERSION}/bin:$PATH
ENV CLASSPATH=/opt/buildtools/bisheng-jdk-${BISHENG_JDK_VERSION%%-*}/lib