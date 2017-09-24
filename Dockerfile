# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# For this Dockerfile to run just provide a private key named cert.key.pem
# and a fullchain named fullchain.pem in the directory wich will be passed
# to the docker damon
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

FROM centos:centos7

MAINTAINER Armin Kunkel <armin@kunkel24.de>

LABEL vendor=avensio \
  org.avensio.nexus.name="Nexus Repository Manager image with ssl only support"

# ARGS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ARG SSL_STOREPASS=changeit
ARG NEXUS_VERSION=3.5.2-01
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz

# configure nexus runtime 1/2
ENV NEXUS_HOME=/opt/nexus/nexus-${NEXUS_VERSION}

# configure nexus runtime 2/2
ENV NEXUS_DATA=/nexus-data \
  NEXUS_CONTEXT='' \
  SONATYPE_WORK=${NEXUS_HOME}/../sonatype-work \
  SSL_WORK=${NEXUS_HOME}/etc/ssl

# configure java runtime
ENV JAVA_HOME=/opt/java \
  JAVA_VERSION_MAJOR=8 \
  JAVA_VERSION_MINOR=144 \
  JAVA_VERSION_BUILD=01 \
  JAVA_DOWNLOAD_HASH=090f390dda5b47b9b721c7dfaa008135

RUN yum install -y \
  curl tar \
  && yum clean all

# install openssl
RUN yum install -y openssl

# copy ssl private key and fullchain certificate
COPY cert.key.pem ${SSL_WORK}/cert.key.pem
COPY fullchain.pem ${SSL_WORK}/fullchain.pem

# copy run script and make it executable (generates server-keystore.jks)
COPY run ${NEXUS_HOME}/bin/run
RUN chmod +x ${NEXUS_HOME}/bin/run

# install Oracle JRE
RUN curl --fail --silent --location --retry 3 \
  --header "Cookie: oraclelicense=accept-securebackup-cookie; " \
  http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/${JAVA_DOWNLOAD_HASH}/server-jre-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz \
  | gunzip \
  | tar -x -C /opt \
  && ln -s /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} ${JAVA_HOME}

# add user nexus
RUN useradd -r -u 200 -m -c "nexus role account" -d ${NEXUS_DATA} -s /bin/false nexus

# install nexus
RUN mkdir -p /opt/nexus \
  && curl --fail --silent --location --retry 3 \
    ${NEXUS_DOWNLOAD_URL} \
  | gunzip \
  | tar x -C ${NEXUS_HOME} --strip-components=1 nexus-${NEXUS_VERSION} \
  && chown -R nexus:nexus ${NEXUS_HOME}/..

# configure nexus and enable ssl
RUN sed \
    -e '/^nexus-context/ s:$:${NEXUS_CONTEXT}:' \
    -e '/nexus-args=/ s/=.*/=${jetty.etc}\/jetty.xml,${jetty.etc}\/jetty-requestlog.xml,${jetty.etc}\/jetty-http.xml,${jetty.etc}\/jetty-https.xml,${jetty.etc}\/jetty-http-redirect-to-https.xml/' \
    -i ${NEXUS_HOME}/etc/nexus-default.properties \
  && sed \
    -e '/^-Xms/d' \
    -e '/^-Xmx/d' \
    -e '/^-XX:MaxDirectMemorySize/d' \
    -i ${NEXUS_HOME}/bin/nexus.vmoptions
RUN echo "application-port-ssl=8443" >> ${NEXUS_HOME}/etc/nexus-default.properties

# configure jetty ssl support
RUN sed 's/<Set name="KeyStorePath">.*<\/Set>/<Set name="KeyStorePath">\/opt\/nexus\/nexus-3.5.2-01\/etc\/ssl\/server-keystore.jks<\/Set>/g' -i ${NEXUS_HOME}/etc/jetty/jetty-https.xml \
    && sed 's/<Set name="KeyStorePassword">.*<\/Set>/<Set name="KeyStorePassword">'"${SSL_STOREPASS}"'<\/Set>/g' -i ${NEXUS_HOME}/etc/jetty/jetty-https.xml \
    && sed 's/<Set name="KeyManagerPassword">.*<\/Set>/<Set name="KeyManagerPassword">'"${SSL_STOREPASS}"'<\/Set>/g' -i ${NEXUS_HOME}/etc/jetty/jetty-https.xml \
    && sed 's/<Set name="TrustStorePath">.*<\/Set>/<Set name="TrustStorePath">\/opt\/nexus\/nexus-3.5.2-01\/etc\/ssl\/server-keystore.jks<\/Set>/g' -i ${NEXUS_HOME}/etc/jetty/jetty-https.xml \
    && sed 's/<Set name="TrustStorePassword">.*<\/Set>/<Set name="TrustStorePassword">'"${SSL_STOREPASS}"'<\/Set>/g' -i ${NEXUS_HOME}/etc/jetty/jetty-https.xml

# generate pkcs12 file
RUN openssl pkcs12 -export \
  -inkey ${SSL_WORK}/*.key.pem \
  -in ${SSL_WORK}/*chain.pem \
  -out ${SSL_WORK}/jetty.pkcs12 \
  -passout pass:${SSL_STOREPASS}

WORKDIR ${JAVA_HOME}/bin

# generate keystore
RUN ./keytool -importkeystore -noprompt \
  -srckeystore ${SSL_WORK}/jetty.pkcs12 \
  -srcstoretype PKCS12 \
  -srcstorepass ${SSL_STOREPASS} \
  -deststorepass ${SSL_STOREPASS} \
  -destkeystore ${SSL_WORK}/server-keystore.jks

RUN mkdir -p ${NEXUS_DATA}/etc ${NEXUS_DATA}/log ${NEXUS_DATA}/tmp ${SONATYPE_WORK} \
  && ln -s ${NEXUS_DATA} ${SONATYPE_WORK}/nexus3 \
  && chown -R nexus:nexus ${NEXUS_DATA}

VOLUME ${NEXUS_DATA}
EXPOSE 8081 8082 8083 8443
USER nexus
WORKDIR ${NEXUS_HOME}

ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

CMD ["bin/nexus", "run"]
