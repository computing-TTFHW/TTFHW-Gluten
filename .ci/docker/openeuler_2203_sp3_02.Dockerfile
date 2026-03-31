# ============================================================
# openEuler 22.03 SP3 应用镜像 (Stage 2)
# 输出镜像: ghcr.io/{owner}/openeuler-build:26330_02
# 基础镜像: ghcr.io/{owner}/openeuler-build:26330_01 (Stage 1)
# 包含:
#   - 基础压缩库: jemalloc, zstd, lz4, snappy, zlib, zlib-ng, cyrus-sasl
#   - JSON 库: nlohmann-json, jsoncpp
#   - 测试工具: googletest
#   - OmniStream 依赖: xxHash, rocksdb
#   - Gluten 依赖: abseil-cpp, re2
#   - 预装依赖: libboundscheck, Native Reader JAR, Arrow 15.0.0 Maven JAR
#   - Jenkins Agent 配置
# ============================================================

# 默认使用华为云 SWR 的镜像作为后备，实际构建时通过 BASE_IMAGE 参数传入 ghcr 镜像
ARG BASE_IMAGE=swr.cn-north-4.myhuaweicloud.com/cloud_boostkit/openeuler22.03_lts_sp3:26330_01
FROM ${BASE_IMAGE}

LABEL maintainer="kunpeng-team"
LABEL description="openEuler 22.03 SP3 application image with dependencies and Jenkins Agent"
LABEL stage="2"
LABEL tag="26330_02"

# ==================== 版本参数 ====================
# 基础压缩库
ARG JEMALLOC_VERSION=5.3.0
ARG ZLIB_VERSION=v1.3.1
ARG LZ4_VERSION=v1.10.0
ARG SNAPPY_VERSION=1.1.10
ARG ZSTD_VERSION=v1.5.6
ARG CYRUS_SASL_VERSION=cyrus-sasl-2.1.28
ARG ZLIB_NG_VERSION=2.0.4

# JSON 库
ARG JSON_VERSION=v3.11.3
ARG JSONCPP_VERSION=1.9.6

# 测试和 OmniStream 依赖
ARG GTEST_VERSION=v1.14.0
ARG XXHASH_VERSION=v0.8.2
ARG ROCKSDB_VERSION=v8.11.4

# Gluten 依赖
ARG ABSEIL_VERSION=20250127.0
ARG RE2_VERSION=2024-07-02

# 预装依赖
ARG LIBBOUNDSCHECK_VERSION=v1.1.16
ARG OMNI_OPERATOR_VERSION=2.1.0
ARG ARROW_VERSION=15.0.0

# OBS 下载地址
ARG OBS_BASE_URL=https://boostkit-bigdata-public.obs.cn-north-4.myhuaweicloud.com/artifact

# Jenkins Agent
ARG JENKINS_VERSION=3107.v665000b_51092
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG AGENT_WORKDIR=/home/${user}/agent

# ==================== 第一层：安装基础压缩库 ====================
# zlib
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/zlib.git \
    && cd zlib && git checkout tags/${ZLIB_VERSION} \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf zlib

# lz4
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/LZ4_old1.git lz4 \
    && cd lz4 && git checkout tags/${LZ4_VERSION} \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf lz4

# zstd
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/facebook-zstd.git zstd \
    && cd zstd && git checkout tags/${ZSTD_VERSION} \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf zstd

# ==================== 第二层：安装 snappy ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/src-openeuler/snappy.git \
    && cd snappy && git checkout tags/openEuler-24.03-LTS-SP1-release \
    && tar -zxvf snappy-${SNAPPY_VERSION}.tar.gz \
    && cd snappy-${SNAPPY_VERSION} \
    && patch -p1 < ../add-option-to-enable-rtti-set-default-to-current-ben.patch \
    && patch -p1 < ../remove-dependency-on-google-benchmark-and-gmock.patch \
    && mkdir -p build \
    && cd build \
    && cmake \
        -DSNAPPY_BUILD_BENCHMARKS=OFF \
        -DSNAPPY_BUILD_TESTS=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        .. \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf snappy

# ==================== 第三层：安装 jemalloc ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/jemalloc.git \
    && cd jemalloc && git checkout tags/${JEMALLOC_VERSION} \
    && ./autogen.sh --disable-initial-exec-tls --with-lg-page=16 \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf jemalloc

# ==================== 第四层：安装 cyrus-sasl ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/cyrus-sasl.git \
    && cd cyrus-sasl && git checkout tags/${CYRUS_SASL_VERSION} \
    && ./autogen.sh \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf cyrus-sasl

# ==================== 第五层：安装 zlib-ng ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://codehub.devcloud.cn-north-4.huaweicloud.com/b40eab964ee243e1a43336403eba828f/OpenSourceCenter/Adaptor/zlib-ng.git \
    && cd zlib-ng && git checkout tags/${ZLIB_NG_VERSION} \
    && ./configure \
    && mkdir build \
    && cd build \
    && cmake \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        ../ \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf zlib-ng

# ==================== 第六层：安装 JSON 库 ====================
# nlohmann-json
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/nlohmann-json.git json \
    && cd json && git checkout tags/${JSON_VERSION} \
    && mkdir build \
    && cd build \
    && cmake ../ \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf json

# jsoncpp
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/jsoncpp.git \
    && cd jsoncpp && git checkout tags/${JSONCPP_VERSION} \
    && mkdir build \
    && cd build \
    && cmake \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_SHARED_LIBS=OFF \
        ../ \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf jsoncpp

# ==================== 第七层：安装测试工具 ====================
# googletest
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/googletest.git \
    && cd googletest && git checkout tags/${GTEST_VERSION} \
    && cmake CMakeLists.txt \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf googletest

# ==================== 第八层：安装 OmniStream 依赖 ====================
# xxHash
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/xxHash_old1.git xxHash \
    && cd xxHash && git checkout tags/${XXHASH_VERSION} \
    && mkdir -p build \
    && cd build \
    && cmake ../cmake_unofficial \
    && cmake --build . \
    && cmake --build . --target install \
    && cd /tmp && rm -rf xxHash

# rocksdb
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/rocksdb.git \
    && cd rocksdb && git checkout tags/${ROCKSDB_VERSION} \
    && mkdir -p build \
    && cd build \
    && cmake .. \
        -DWITH_SNAPPY=1 \
        -DCMAKE_BUILD_TYPE=Release \
        -DUSE_RTTI=1 \
        -DWITH_GFLAGS=0 \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf rocksdb

# ==================== 第九层：安装 Gluten 依赖 ====================
# abseil-cpp
RUN set -ex && \
    mkdir -p /opt/Gluten \
    && cd /tmp \
    && git clone https://gitee.com/mirrors/abseil-cpp.git \
    && cd abseil-cpp && git checkout tags/${ABSEIL_VERSION} \
    && mkdir -p build \
    && cd build \
    && cmake .. \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DABSL_PROPAGATE_CXX_STD=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_CXX_FLAGS="-fPIC" \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf abseil-cpp

# re2
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/re2.git \
    && cd re2 && git checkout tags/${RE2_VERSION} \
    && mkdir build \
    && cd build \
    && cmake .. -DBUILD_SHARED_LIBS=ON \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf re2

# ==================== 第十层：安装 libboundscheck ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitcode.com/openeuler/libboundscheck.git \
    && cd libboundscheck && git checkout tags/${LIBBOUNDSCHECK_VERSION} \
    && make CC=gcc \
    && cp lib/*.so /usr/local/lib/ \
    && cp -r include /usr/local/libboundscheck-include \
    && cd /tmp && rm -rf libboundscheck

# ==================== 第十一层：预装 Native Reader JAR ====================
# master 分支版本
RUN set -ex && \
    mkdir -p /root/.m2/repository/com/huawei/boostkit/boostkit-omniop-native-reader/3.4.3-${OMNI_OPERATOR_VERSION} \
    && wget -O /tmp/native-reader.jar \
        "${OBS_BASE_URL}/omniop_native_reader/br_feature_omnioperator_spark_2026_330/Daily.26.0.0.B001/boostkit-omniop-native-reader-3.4.3-${OMNI_OPERATOR_VERSION}.jar" \
    && cp /tmp/native-reader.jar \
        /root/.m2/repository/com/huawei/boostkit/boostkit-omniop-native-reader/3.4.3-${OMNI_OPERATOR_VERSION}/ \
    && rm -rf /tmp/*.jar

# ==================== 第十二层：预装 Arrow 15.0.0 Maven JAR ====================
RUN set -ex && \
    mkdir -p /root/.m2/repository/org/apache \
    && cd /root/.m2/repository/org/apache \
    && wget "${OBS_BASE_URL}/Gluten/Compile_Rely/arrow-${ARROW_VERSION}.zip" \
    && unzip -o arrow-${ARROW_VERSION}.zip \
    && rm -rf arrow-${ARROW_VERSION}.zip

# ==================== 第十三层：安装 Jenkins Agent ====================
RUN set -ex && \
    # 下载 Jenkins remoting jar
    curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar \
        https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${JENKINS_VERSION}/remoting-${JENKINS_VERSION}.jar \
    && chmod 755 /usr/share/jenkins \
    && chmod 644 /usr/share/jenkins/agent.jar \
    && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar \
    # 下载 Jenkins agent 脚本
    && curl --create-dirs -fsSLo /usr/local/bin/jenkins-agent \
        http://121.36.53.23/AdoptOpenJDK/jenkins-agent \
    && chmod a+rx /usr/local/bin/jenkins-agent \
    && ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave \
    # 创建 Jenkins 用户
    && groupadd -g ${gid} ${group} \
    && useradd -c "Jenkins user" -d /home/${user} -u ${uid} -g ${gid} -m ${user} \
    && echo "${user} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/${user}/.jenkins \
    && mkdir -p ${AGENT_WORKDIR} \
    && mkdir -p /tmp \
    && chown -R ${uid}:${gid} /tmp \
    && chmod -R 755 /tmp

# ==================== 第十四层：收集依赖产物 ====================
RUN set -ex && \
    os_version=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | sed -E 's/"([A-Za-z0-9]+) ([0-9]+\.[0-9]+).*/\1\2/') \
    # Adaptor Dependencies - 移除 Arrow/ORC/Hadoop 相关库
    && mkdir -p /opt/Dependencies_${os_version}_Adaptor \
    && cd /opt/Dependencies_${os_version}_Adaptor \
    && cp /opt/buildtools/LLVM-15.0.4/lib/libLLVM-15.so ./ \
    && cp /usr/local/lib/libjemalloc.so.2 ./ \
    && cp /usr/local/lib64/libsnappy.so.1.1.10 ./libsnappy.so.1 \
    && cp /usr/local/lib/liblz4.so.1.10.0 ./liblz4.so.1 \
    && cp /opt/buildtools/Protobuf-3.21.9/lib/libprotobuf.so.32.0.9 ./libprotobuf.so.32 \
    && cp /usr/local/lib/libz.so.1.3.1 ./libz.so.1 \
    && cp /usr/local/lib/libzstd.so.1.5.6 ./libzstd.so.1 \
    # Gluten Dependencies
    && cd /opt \
    && mkdir -p /opt/Dependencies_${os_version}_Gluten \
    && cd /opt/Dependencies_${os_version}_Gluten \
    && cp /opt/buildtools/Protobuf-3.21.9/lib/libprotobuf.so.32.0.9 ./libprotobuf.so.32 \
    && cp /opt/buildtools/LLVM-15.0.4/lib/libLLVM-15.so ./ \
    && cp /usr/local/lib64/libre2.so.11.0.0 ./libre2.so.11 \
    # OmniStream Dependencies
    && cd /opt \
    && mkdir -p /opt/Dependencies_${os_version}_OmniStream \
    && cd /opt/Dependencies_${os_version}_OmniStream \
    && cp /usr/local/lib/libjemalloc.so.2 ./ \
    && cp /opt/buildtools/LLVM-15.0.4/lib/libLLVM-15.so ./ \
    && cp /usr/local/lib64/libxxhash.so.0.8.2 ./libxxhash.so.0 \
    && cp /usr/lib64/librocksdb.so.8.11.4 ./librocksdb.so.8 \
    && cp /usr/local/lib64/libsnappy.so.1.1.10 ./libsnappy.so.1 \
    && rm -rf /tmp/*

# ==================== 环境变量 ====================
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
ENV LIBBOUNDSCHECK_HOME=/usr/local

# 添加 libboundscheck 到包含路径
ENV C_INCLUDE_PATH=/usr/local/libboundscheck-include:${C_INCLUDE_PATH}
ENV CPLUS_INCLUDE_PATH=/usr/local/libboundscheck-include:${CPLUS_INCLUDE_PATH}

# ==================== 切换用户 ====================
USER ${user}

VOLUME ~/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR ${AGENT_WORKDIR}

ENTRYPOINT ["jenkins-agent"]