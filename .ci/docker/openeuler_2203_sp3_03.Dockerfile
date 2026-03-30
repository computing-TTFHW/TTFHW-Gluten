# ============================================================
# openEuler 22.03 SP3 Jenkins Agent 镜像 (Stage 3)
# 包含: JDK8, fmt, folly, Jenkins Agent (JDK17)
# 依赖: Stage 2 (02.Dockerfile) 的构建产物
# ============================================================

ARG BASE_IMAGE=swr.cn-north-4.myhuaweicloud.com/cloud_boostkit/openeuler22.03_lts_sp3:26330_02
FROM ${BASE_IMAGE}

LABEL maintainer="kunpeng-team"
LABEL description="openEuler 22.03 SP3 Jenkins agent with JDK8, fmt, folly"
LABEL stage="3"
LABEL version="1.0"

# ==================== 版本参数 ====================
ARG JDK8_VERSION=462
ARG JDK8_BUILD=b08
ARG JDK17_VERSION=17
ARG MAVEN_VERSION=3.8.3
ARG LLVM_VERSION=15.0.4
ARG CMAKE_VERSION=3.28.2
ARG FMT_VERSION=10.1.1
ARG FOLLY_VERSION=v2024.07.01.00
ARG JENKINS_VERSION=3107.v665000b_51092

# ==================== 用户参数 ====================
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG AGENT_WORKDIR=/home/${user}/agent

# ==================== 环境变量 ====================
ENV JAVA_HOME=/opt/buildtools/openjdk8/jdk8u${JDK8_VERSION}-${JDK8_BUILD}
ENV JRE_HOME=/opt/buildtools/openjdk8/jdk8u${JDK8_VERSION}-${JDK8_BUILD}/jre
ENV MAVEN_HOME=/opt/buildtools/apache-maven/apache-maven-${MAVEN_VERSION}
ENV LLVM_HOME=/opt/buildtools/LLVM-${LLVM_VERSION}
ENV PATH=/opt/buildtools/cmake-${CMAKE_VERSION}-linux-aarch64/bin:${LLVM_HOME}/bin:${MAVEN_HOME}/bin:${JAVA_HOME}/bin:$PATH
ENV CLASSPATH=${JAVA_HOME}/lib:$CLASSPATH
ENV LANG=C.utf8
ENV LC_ALL=C.utf8
ENV LANGUAGE=C.utf8
ENV AGENT_WORKDIR=${AGENT_WORKDIR}

# ==================== 第一层：安装系统包 ====================
RUN set -ex && \
    yum install -y \
        double-conversion-devel \
        libevent-devel \
        glog-devel \
        perf \
        binutils \
        binutils-devel \
        tree \
        dos2unix \
        doxygen \
        ccache \
        ninja-build \
        patchelf \
        sudo \
        wget \
        curl \
        tar \
        git \
        python3-pip \
    && dnf reinstall -y --allowerasing glibc-common \
    && dnf install -y texinfo \
    && locale \
    && yum clean all \
    && rm -rf /var/cache/yum

# ==================== 第二层：安装 JDK8 ====================
RUN set -ex && \
    mkdir -p /opt/buildtools/openjdk8 \
    && cd /opt/buildtools/openjdk8 \
    && wget https://buildtools.obs.cn-north-4.myhuaweicloud.com/OpenJDK8U-jdk_aarch64_linux_hotspot_8u${JDK8_VERSION}${JDK8_BUILD}.tar.gz \
    && tar -xf OpenJDK8U-jdk_aarch64_linux_hotspot_8u${JDK8_VERSION}${JDK8_BUILD}.tar.gz \
    && rm -rf OpenJDK8U-jdk_aarch64_linux_hotspot_8u${JDK8_VERSION}${JDK8_BUILD}.tar.gz

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

# ==================== 第四层：安装 fmt 库 ====================
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

# ==================== 第五层：安装 folly 库 ====================
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

# ==================== 第六层：安装 Jenkins Agent ====================
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
    # 安装 JDK17 (Jenkins Agent 运行需要)
    && wget -q https://mirrors.huaweicloud.com/openjdk/${JDK17_VERSION}/openjdk-${JDK17_VERSION}_linux-aarch64_bin.tar.gz -O /tmp/jdk17.tar.gz \
    && mkdir -p /usr/local \
    && tar -xzf /tmp/jdk17.tar.gz -C /usr/local \
    && rm /tmp/jdk17.tar.gz \
    && mv /usr/local/jdk-${JDK17_VERSION} /usr/local/openjdk-${JDK17_VERSION} \
    && chmod a+rx /usr/local/openjdk-${JDK17_VERSION} \
    && ln -sf /usr/local/openjdk-${JDK17_VERSION}/bin/java /usr/local/bin/java \
    # 创建 Jenkins 用户
    && groupadd -g ${gid} ${group} \
    && useradd -c "Jenkins user" -d /home/${user} -u ${uid} -g ${gid} -m ${user} \
    && echo "${user} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/${user}/.jenkins \
    && mkdir -p ${AGENT_WORKDIR} \
    && mkdir -p /tmp \
    && chown -R ${uid}:${gid} /tmp \
    && chmod -R 755 /tmp

# ==================== 切换用户 ====================
USER ${user}

VOLUME ~/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR ${AGENT_WORKDIR}

ENTRYPOINT ["jenkins-agent"]