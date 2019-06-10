FROM alpine:3.9
LABEL maintainer="Ank"

ENV JAVA_HOME="/usr/lib/jvm/default-jvm"
ENV GRADLE_OPTS="-server -Xmx2g -XX:+UseParallelGC -Xms1g -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99 -Dorg.gradle.daemon=false"
ENV JAVA_OPTS="$JAVA_OPTS -Dorg.apache.el.parser.SKIP_IDENTIFIER_CHECK=true"
ENV TOMCAT_MAJOR=8 \
    TOMCAT_VERSION=8.5.3 \
    TOMCAT_HOME=/opt/tomcat \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_OUT=/dev/null

RUN apk add --no-cache openjdk8-jre && \
    ln -sf "${JAVA_HOME}/bin/"* "/usr/bin/"

RUN apk upgrade --update && \
    apk add --update curl && \
    curl -jksSL -o /tmp/apache-tomcat.tar.gz http://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz && \
    gunzip /tmp/apache-tomcat.tar.gz && \
    tar -C /opt -xf /tmp/apache-tomcat.tar && \
    ln -s /opt/apache-tomcat-${TOMCAT_VERSION} ${TOMCAT_HOME}
    
# RUN rm -rf ${TOMCAT_HOME}/webapps/* && \
RUN apk del curl && \
    rm -rf /tmp/* /var/cache/apk/*

COPY ./configs/* /opt/tomcat/conf/

WORKDIR /opt/tomcat
EXPOSE 8080
ENTRYPOINT ["./bin/catalina.sh", "run"]