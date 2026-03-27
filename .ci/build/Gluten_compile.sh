set -ex

export OMNI_HOME=$(pwd)
mkdir -p $OMNI_HOME/lib/include
# mv ${WORKSPACE}/BoostKit_CI/maven/Gluten_settings.xml /opt/buildtools/apache-maven/apache-maven-3.9.9/conf/settings.xml
agentpath="${WORKSPACE}/toCMC"
if [ -d "${agentpath}" ];then rm -rf ${agentpath}; fi
mkdir -p ${agentpath}/software
mkdir -p ${agentpath}/inner 
OmniOperatorJIT_Version=2.1.0
OS_type=openeuler-sve



export JAVA_HOME=/opt/buildtools/openjdk8/jdk8u462-b08
export JRE_HOME=/opt/buildtools/openjdk8/jdk8u462-b08/jre
export MAVEN_HOME=/opt/buildtools/apache-maven/apache-maven-3.9.9
export LLVM_HOME=/opt/buildtools/LLVM-15.0.4 
export PATH=/opt/buildtools/cmake-3.28.2-linux-aarch64/bin:/opt/buildtools/LLVM-15.0.4/bin:/opt/buildtools/apache-maven/apache-maven-3.9.9/bin:/opt/buildtools/openjdk8/jdk8u462-b08/bin:/opt/buildtools/openjdk8/jdk8u462-b08/jre/bin:$PATH
export CLASSPATH=/opt/buildtools/openjdk8/jdk8u462-b08/lib:$/opt/buildtools/openjdk8/jdk8u462-b08/jre/lib:$CLASSPATH
export PROTOBUF_HOME=/opt/buildtools/Protobuf-3.21.9
export PATH=$PROTOBUF_HOME/bin:$PATH
export CMAKE_PREFIX_PATH=$PROTOBUF_HOME
export Protobuf_ROOT=$PROTOBUF_HOME
export Protobuf_PROTOC_EXECUTABLE=$PROTOBUF_HOME/bin/protoc
export FMT_HOME=/usr/local
export FOLLY_HOME=/usr/local
sudo ln -sf $PROTOBUF_HOME/bin/protoc /usr/local/bin/
protoc --version

function huawei_secure_c(){
    pushd huawei_secure_c/src && make && popd
    cp -rf huawei_secure_c $OMNI_HOME/lib/ && cp -rf huawei_secure_c $OMNI_HOME/lib/include/
}

function compile_libboundscheck(){
    pushd libboundscheck && make CC=gcc && popd
    export LD_LIBRARY_PATH=$OMNI_HOME/libboundscheck/lib:$LD_LIBRARY_PATH
    export LIBRARY_PATH=$OMNI_HOME/libboundscheck/lib:$LIBRARY_PATH
    export C_INCLUDE_PATH=$OMNI_HOME:$C_INCLUDE_PATH
    export CPLUS_INCLUDE_PATH=$OMNI_HOME:$CPLUS_INCLUDE_PATH
}

function native_reader(){
    echo "native-reader 部署"
    mkdir -p ${WORKSPACE}/gluten/3rdparty/ && pushd ${WORKSPACE}/gluten/3rdparty/ 
    if [ "${gluten_branch}" == "2026_330_poc" ];then 
        echo "gluten已经消减对native-reader的直接依赖" 
    else
        wget https://boostkit-bigdata-public.obs.cn-north-4.myhuaweicloud.com/artifact/omniop_native_reader/br_feature_omnioperator_spark_2026_330/Daily.26.0.0.B001/boostkit-omniop-native-reader-3.4.3-${OmniOperatorJIT_Version}.jar
        mvn install:install-file -DgroupId=com.huawei.boostkit -DartifactId=boostkit-omniop-native-reader -Dversion=3.4.3-${OmniOperatorJIT_Version} -Dpackaging=jar \
            -Dfile=${WORKSPACE}/gluten/3rdparty/boostkit-omniop-native-reader-3.4.3-${OmniOperatorJIT_Version}.jar 
    fi
    popd
}

function compile_prepare(){
    echo "OmniOperator 部署"
    mkdir -p ${WORKSPACE}/output/operator_${OS_type} 
    if [ "${gluten_branch}" == "2026_330_poc" ];then 
        wget https://boostkit-bigdata-public.obs.cn-north-4.myhuaweicloud.com/artifact/OmniOperator/2026_330_poc/Daily.26.0.0.B001/BoostKit-omniruntime-omnioperator-${OmniOperatorJIT_Version}.zip
    elif [ "${gluten_branch}" == "master" ];then
        wget https://boostkit-bigdata-public.obs.cn-north-4.myhuaweicloud.com/artifact/OmniOperator/master/Daily.26.0.0.B001/BoostKit-omniruntime-omnioperator-${OmniOperatorJIT_Version}.zip
    else
        wget https://boostkit-bigdata-public.obs.cn-north-4.myhuaweicloud.com/artifact/OmniOperator/${OmniOperatorJIT_branch}/Daily.26.0.0.B001/BoostKit-omniruntime-omnioperator-${OmniOperatorJIT_Version}.zip
    fi
    unzip -o BoostKit-omniruntime-omnioperator-${OmniOperatorJIT_Version}.zip 
    tar -xf boostkit-omniop-operator-${OmniOperatorJIT_Version}-aarch64-${OS_type}.tar.gz && cp -rf boostkit-omniop-operator-${OmniOperatorJIT_Version}-aarch64 ${WORKSPACE}/output/operator_${OS_type}
    mvn install:install-file -DgroupId=com.huawei.boostkit -Dclassifier=aarch64 -DartifactId=boostkit-omniop-udf -Dversion=${OmniOperatorJIT_Version} \
        -Dfile=${WORKSPACE}/output/operator_${OS_type}/boostkit-omniop-operator-${OmniOperatorJIT_Version}-aarch64/boostkit-omniop-udf-${OmniOperatorJIT_Version}-aarch64.jar -Dpackaging=jar
    mvn install:install-file -DgroupId=com.huawei.boostkit -Dclassifier=aarch64 -DartifactId=boostkit-omniop-bindings -Dversion=${OmniOperatorJIT_Version} \
        -Dfile=${WORKSPACE}/output/operator_${OS_type}/boostkit-omniop-operator-${OmniOperatorJIT_Version}-aarch64/boostkit-omniop-bindings-${OmniOperatorJIT_Version}-aarch64.jar -Dpackaging=jar
    cp -rf ${WORKSPACE}/output/operator_${OS_type}/boostkit-omniop-operator-${OmniOperatorJIT_Version}-aarch64/include/* $OMNI_HOME/lib/include
    cp -rf ${WORKSPACE}/output/operator_${OS_type}/boostkit-omniop-operator-${OmniOperatorJIT_Version}-aarch64/*.so $OMNI_HOME/lib/
}

function arrow(){
    pushd ~/.m2/repository/org/apache/
    wget https://boostkit-bigdata-public.obs.cn-north-4.myhuaweicloud.com/artifact/Gluten/Compile_Rely/arrow-15.0.0.zip
    unzip -o arrow-15.0.0.zip && popd
}

function Gluten_compile(){
    compile_libboundscheck
    native_reader
    compile_prepare
    arrow

    export LD_LIBRARY_PATH=${PROTOBUF_HOME}/lib:/opt/Gluten/lib:/opt/Gluten/lib64:$OMNI_HOME/lib:$LD_LIBRARY_PATH
    export LIBRARY_PATH=${PROTOBUF_HOME}/lib:/opt/Gluten/lib:/opt/Gluten/lib64:$OMNI_HOME/lib:$LIBRARY_PATH
    export C_INCLUDE_PATH=/usr/local/include/orc:$LLVM_HOME/include:${PROTOBUF_HOME}/include:/opt/Gluten/include:$OMNI_HOME/lib/include:$C_INCLUDE_PATH
    export CPLUS_INCLUDE_PATH=/usr/local/include/orc:$LLVM_HOME/include:${PROTOBUF_HOME}/include:/opt/Gluten/include:$OMNI_HOME/lib/include:$CPLUS_INCLUDE_PATH
    pushd ${WORKSPACE}/gluten && ls -al && chmod -R +x cpp-omni/build.sh && bash cpp-omni/build.sh 
    if [ "${gluten_branch}" == "2026_330_poc" ];then 
        spark_version=3.5
    else
        spark_version=3.4
    fi
    mvn clean package -Pbackends-omni -Pspark-${spark_version} -DskipTests -Piceberg -Dspotless.check.skip=true -Dscalastyle.skip=true -Dcheckstyle.skip=true
    popd
}

function BoostKit_gluten_Version_info(){
    touch version.txt
    echo "Product Name: Kunpeng BoostKit" >> version.txt
    echo "Product Version: ${Product_Version}" >> version.txt
    echo "Component Name: BoostKit-gluten" >> version.txt
    echo "Component Version: 2.0.0" >> version.txt
} 

function dopackage(){
    pushd ${WORKSPACE}/
    cp BoostKit_CI/SpecifiedFunction/Retrieve_source_code.py ./
    python3 Retrieve_source_code.py
    cp repositories_info.json ${agentpath}/inner
    mkdir -p ${WORKSPACE}/tmppackage
    cp ${WORKSPACE}/gluten/cpp-omni/build/releases/libspark_columnar_plugin.so ${WORKSPACE}/tmppackage/
    cp ${WORKSPACE}/gluten/package/target/gluten-omni-bundle-spark*_2.12-openEuler_22.03_aarch_64-1.3.0.jar ${WORKSPACE}/tmppackage/
    cp ${WORKSPACE}/libboundscheck/lib/*.so ${WORKSPACE}/tmppackage/
    cp ${WORKSPACE}/BoostKit-omniruntime-omnioperator-${OmniOperatorJIT_Version}.zip ${WORKSPACE}/tmppackage/
    if [ -f "${WORKSPACE}/gluten/3rdparty/boostkit-omniop-native-reader-*-${OmniOperatorJIT_Version}.jar" ];then 
        cp ${WORKSPACE}/gluten/3rdparty/boostkit-omniop-native-reader-*-${OmniOperatorJIT_Version}.jar ${WORKSPACE}/tmppackage/
    fi
    pushd ${WORKSPACE}/tmppackage && BoostKit_gluten_Version_info && zip -r BoostKit-omniruntime-gluten-2.0.0.zip ./* && popd
    cp ${WORKSPACE}/tmppackage/BoostKit-omniruntime-gluten-2.0.0.zip ${agentpath}/software
    mkdir -p ${agentpath}/inner/Dependency_library_Gluten
    cp -rvf /opt/Dependencies_openEuler22.03_Gluten/* ${agentpath}/inner/Dependency_library_Gluten
    cp -rvf /opt/Dependencies_openEuler22.03_Adaptor/* ${agentpath}/inner/Dependency_library_Gluten
    pushd ${WORKSPACE}/toCMC && zip -r gluten.zip ./* && popd

    pushd ${agentpath}/inner/ && zip -r Dependency_library_Gluten.zip Dependency_library_Gluten && cp Dependency_library_Gluten.zip ${agentpath}/software && popd
    pushd ${agentpath}/software
    #########生成json文件#########################
    python3 ${WORKSPACE}/BoostKit_CI/SpecifiedFunction/collect_software_info.py ${WORKSPACE}/BoostKit_CI/sourcecode/bigdata/code.xml ${WORKSPACE} BoostKit-omniruntime-gluten-2.0.0.zip
    python3 ${WORKSPACE}/BoostKit_CI/SpecifiedFunction/collect_software_info.py ${WORKSPACE}/BoostKit_CI/sourcecode/bigdata/code.xml ${WORKSPACE} Dependency_library_Gluten.zip
    ###############end############################
    popd
}
 
function Gluten_build(){
    parameter="$1"
    case ${parameter} in 
        "compile")
           Gluten_compile
            ;;
        "coverages_cpp")
            ut_Gluten
            ;;
        "package")
            Gluten_compile
            dopackage
    esac
}

Gluten_build $@
