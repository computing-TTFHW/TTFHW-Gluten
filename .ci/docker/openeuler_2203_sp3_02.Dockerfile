# ============================================================
# openEuler 22.03 SP3 应用依赖镜像 (Stage 2)
# 包含: Arrow, ORC, Hadoop, jemalloc, zstd, lz4, snappy,
#       json, jsoncpp, zlib, zlib-ng, cyrus-sasl, googletest,
#       xxHash, rocksdb, abseil-cpp, re2
# 依赖: Stage 1 (01.Dockerfile) 的构建产物
# ============================================================

ARG BASE_IMAGE=swr.cn-north-4.myhuaweicloud.com/cloud_boostkit/openeuler22.03_lts_sp3:26330_01
FROM ${BASE_IMAGE}

LABEL maintainer="kunpeng-team"
LABEL description="openEuler 22.03 SP3 application dependencies image"
LABEL stage="2"
LABEL version="1.0"

# ==================== 版本参数 ====================
ARG ARROW_VERSION=apache-arrow-11.0.0
ARG JSON_VERSION=v3.11.3
ARG JEMALLOC_VERSION=5.3.0
ARG ZLIB_VERSION=v1.3.1
ARG LZ4_VERSION=v1.10.0
ARG SNAPPY_VERSION=1.1.10
ARG ZSTD_VERSION=v1.5.6
ARG CYRUS_SASL_VERSION=cyrus-sasl-2.1.28
ARG ZLIB_NG_VERSION=2.0.4
ARG JSONCPP_VERSION=1.9.6
ARG ORC_VERSION=v1.7.4_new
ARG HADOOP_VERSION=rel/release-3.2.0
ARG GTEST_VERSION=v1.14.0
ARG XXHASH_VERSION=v0.8.2
ARG ROCKSDB_VERSION=v8.11.4
ARG ABSEIL_VERSION=20250127.0
ARG RE2_VERSION=2024-07-02

# ==================== 公共环境变量 ====================
ENV REPO_URL_CI=""
ENV REPO_URL_BMC=""
ENV INSTALL_LINUX_DIR="/tmp"

# ==================== 构建环境变量 ====================
ENV JAVA_HOME=/opt/buildtools/bisheng-jdk-21.0.9
ENV MAVEN_HOME=/opt/buildtools/apache-maven/apache-maven-3.9.9
ENV LLVM_HOME=/opt/buildtools/LLVM-15.0.4
ENV CMAKE_ROOT=/opt/buildtools/cmake-3.28.2-linux-aarch64/share
ENV PROTOBUF_HOME=/opt/buildtools/Protobuf-3.21.9
ENV PATH=/opt/buildtools/cmake-3.28.2-linux-aarch64/bin:/opt/buildtools/LLVM-15.0.4/bin:/opt/buildtools/apache-maven/apache-maven-3.9.9/bin:/opt/buildtools/bisheng-jdk-21.0.9/bin:/opt/buildtools/Protobuf-3.21.9/bin:$PATH

# ==================== 第一层：安装系统依赖 ====================
RUN set -ex && \
    echo "140.82.112.4 github.com" >> /etc/hosts \
    && yum install -y openssl \
    && yum clean all

# ==================== 第二层：安装基础压缩库 ====================
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

# ==================== 第三层：安装 snappy ====================
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

# ==================== 第四层：安装 jemalloc ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/jemalloc.git \
    && cd jemalloc && git checkout tags/${JEMALLOC_VERSION} \
    && ./autogen.sh --disable-initial-exec-tls --with-lg-page=16 \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf jemalloc

# ==================== 第五层：安装 cyrus-sasl ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/cyrus-sasl.git \
    && cd cyrus-sasl && git checkout tags/${CYRUS_SASL_VERSION} \
    && ./autogen.sh \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf cyrus-sasl

# ==================== 第六层：安装 zlib-ng ====================
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

# ==================== 第七层：安装 JSON 库 ====================
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

# ==================== 第八层：安装 Arrow ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/kunpengcompute/boostkit-bigdata.git -b main \
    && git clone https://gitee.com/mirrors/Apache-Arrow.git arrow \
    && cd arrow && git checkout tags/${ARROW_VERSION} && cd .. \
    && cp boostkit-bigdata/omnioperator/contrib/arrow-maint-11_0_0/arrow-maint-11_0_0.patch ./arrow/ \
    && cd arrow && git apply arrow-maint-11_0_0.patch && cd .. \
    && mkdir -p arrow/cpp/_build \
    && cd arrow/cpp/_build \
    && cmake \
        -DARROW_JEMALLOC_LG_PAGE=16 \
        -DARROW_BUILD_INTEGRATION=OFF \
        -DARROW_BUILD_STATIC=OFF \
        -DARROW_BUILD_TESTS=OFF \
        -DARROW_ENABLE_TIMING_TESTS=OFF \
        -DARROW_COMPUTE=ON \
        -DARROW_DATASET=ON \
        -DARROW_EXTRA_ERROR_CONTEXT=ON \
        -DARROW_MIMALLOC=ON \
        -DARROW_SUBSTRAIT=ON \
        -DARROW_WITH_BROTLI=ON \
        -DARROW_WITH_BZ2=ON \
        -DARROW_WITH_LZ4=ON \
        -DARROW_WITH_SNAPPY=ON \
        -DARROW_WITH_UTF8POC=ON \
        -DARROW_WITH_ZLIB=ON \
        -DARROW_WITH_ZSTD=ON \
        -DARROW_HDFS=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -S .. -B . \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf arrow boostkit-bigdata

# ==================== 第九层：安装 ORC ====================
RUN set -ex && \
    export ZSTD_HOME=/usr/local \
    && export LZ4_HOME=/usr/local \
    && export ZLIB_HOME=/usr/local \
    && export ZLIB_NG_HOME=/usr/local \
    && export SNAPPY_HOME=/usr/local \
    && mkdir -p /opt/Adaptor/lib/include/ \
    && cd /tmp \
    && git clone https://codehub.devcloud.cn-north-4.huaweicloud.com/b40eab964ee243e1a43336403eba828f/OpenSourceCenter/Adaptor/orc.git -b ${ORC_VERSION} \
    && cd orc \
    && mkdir build \
    && cd build \
    && cmake ../ \
        -DBUILD_JAVA=OFF \
        -DANALYZE_JAVA=OFF \
        -DBUILD_LIBHDFSPP=OFF \
        -DBUILD_CPP_TESTS=OFF \
        -DBUILD_TOOLS=ON \
        -DBUILD_POSITION_INDEPENDENT_LIB=ON \
    && make -j$(nproc) \
    && make install \
    && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/opt/buildtools/Protobuf-3.21.9/lib:/usr/local/lib \
    && gcc -shared -fPIC -o liborc.so \
        -Wl,--whole-archive /usr/local/lib/liborc.a \
        -Wl,--no-whole-archive \
        -L/opt/buildtools/Protobuf-3.21.9/lib \
        -L/usr/local/lib \
        -L/usr/local/lib64 \
        -lsasl2 -lssl -lcrypto -lpthread -lprotobuf -lsnappy -lzstd -lz-ng -llz4 \
    && ldd -r liborc.so \
    && cp liborc.so /usr/local/lib/ \
    && cd .. \
    && cp -rf /usr/local/include/orc/* /opt/Adaptor/lib/include/ \
    && cd /tmp && rm -rf orc

# ==================== 第十层：安装 Hadoop ====================
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/hadoop.git \
    && cd hadoop && git checkout tags/${HADOOP_VERSION} && cd .. \
    && git clone https://gitee.com/kunpengcompute/boostkit-bigdata.git -b main \
    && cp boostkit-bigdata/omnioperator/contrib/hadoop-3_2_0/hadoop-3_2_0.patch hadoop \
    && cd hadoop && git apply hadoop-3_2_0.patch && cd .. \
    && cd hadoop/hadoop-hdfs-project/hadoop-hdfs-native-client/ \
    && sed -i "172d" src/CMakeLists.txt \
    && sed -i "155d" src/CMakeLists.txt \
    && mvn clean package -DskipTests -Pdist,native -Dtar \
    && cd /tmp \
    && mkdir -p /opt/Adaptor \
    && export OMNI_HOME=/opt/Adaptor/ \
    && cp -rf hadoop/hadoop-hdfs-project/hadoop-hdfs-native-client/src/main/native/libhdfs/include/* $OMNI_HOME/lib/include/ \
    && cp -rf hadoop/hadoop-hdfs-project/hadoop-hdfs-native-client/target/target/usr/local/lib/* $OMNI_HOME/lib \
    && cp -rf hadoop/hadoop-hdfs-project/hadoop-hdfs-native-client/target/hadoop-hdfs-native-client-3.2.0/include/* $OMNI_HOME/lib/include/ \
    && rm -rf hadoop boostkit-bigdata

# ==================== 第十一层：安装测试工具 ====================
# googletest
RUN set -ex && \
    cd /tmp \
    && git clone https://gitee.com/mirrors/googletest.git \
    && cd googletest && git checkout tags/${GTEST_VERSION} \
    && cmake CMakeLists.txt \
    && make -j$(nproc) \
    && make install \
    && cd /tmp && rm -rf googletest

# ==================== 第十二层：安装 OmniStream 依赖 ====================
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

# ==================== 第十三层：安装 Gluten 依赖 ====================
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

# ==================== 第十四层：收集依赖产物 ====================
RUN set -ex && \
    os_version=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | sed -E 's/"([A-Za-z0-9]+) ([0-9]+\.[0-9]+).*/\1\2/') \
    # Adaptor Dependencies
    && mkdir -p /opt/Dependencies_${os_version}_Adaptor \
    && cd /opt/Dependencies_${os_version}_Adaptor \
    && cp /opt/buildtools/LLVM-15.0.4/lib/libLLVM-15.so ./ \
    && cp /usr/local/lib/libjemalloc.so.2 ./ \
    && cp /usr/local/lib64/libarrow_dataset.so.1100.0.0 ./libarrow_dataset.so.1100 \
    && cp /usr/local/lib64/libarrow.so.1100.0.0 ./libarrow.so.1100 \
    && cp /usr/local/lib64/libarrow_substrait.so.1100.0.0 ./libarrow_substrait.so.1100 \
    && cp /usr/local/lib64/libparquet.so.1100.0.0 ./libparquet.so.1100 \
    && cp /usr/local/lib64/libsnappy.so.1.1.10 ./libsnappy.so.1 \
    && cp /usr/local/lib/liblz4.so.1.10.0 ./liblz4.so.1 \
    && cp /opt/buildtools/Protobuf-3.21.9/lib/libprotobuf.so.32.0.9 ./libprotobuf.so.32 \
    && cp /usr/local/lib/libz.so.1.3.1 ./libz.so.1 \
    && cp /usr/local/lib/liborc.so ./ \
    && cp /opt/Adaptor/lib/libhdfs.so.0.0.0 ./ \
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