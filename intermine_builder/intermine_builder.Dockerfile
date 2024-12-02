FROM alpine:3.20

ENV JAVA_HOME="/usr/lib/jvm/default-jvm"

RUN apk add --no-cache \
  build-base \
  maven \
  openjdk11 \
  perl \
  perl-app-cpm \
  perl-datetime \
  perl-html-parser \
  perl-html-tree \
  perl-io-gzip \
  perl-libwww \
  perl-libxml-perl \
  perl-list-moreutils-xs \
  perl-module-build \
  perl-module-build-tiny \
  perl-module-find \
  perl-moose \
  perl-moosex \
  perl-moosex-types \
  perl-package-stash \
  perl-sub-identify \
  perl-text-csv_xs \
  perl-text-glob \
  perl-uri \
  perl-utils \
  perl-xml-dom \
  perl-xml-libxml \
  perl-xml-parser

# perl-number-format in alpine edge
RUN cpm install -g \
  Ouch \
  Web::Scraper \
  Number::Format \
  Perl6::Junction \
  MooseX::FollowPBP \
  MooseX::ABC \
  MooseX::FileAttribute

RUN mkdir -m 777 /home/intermine && mkdir -m 777 /home/intermine/intermine

ENV MEM_OPTS="-Xmx2g -Xms1g"
ENV GRADLE_OPTS="-server ${MEM_OPTS} -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99 -Dorg.gradle.daemon=false -Duser.home=/home/intermine"
ENV HOME="/home/intermine"
ENV USER_HOME="/home/intermine"
ENV GRADLE_USER_HOME="/home/intermine/.gradle"

SHELL ["/bin/sh", "-euc"]

# Build intermine
COPY ./intermine /home/intermine/.intermine
WORKDIR /home/intermine/.intermine
RUN --mount=type=cache,target=/home/intermine/.gradle \
  for dir in plugin intermine bio bio/sources bio/postprocess; \
  do \
    (cd ${dir} && ./gradlew install && ./gradlew clean) \
  done

# Build lis-bio-sources
COPY ./lis-bio-sources /mnt/lis-bio-sources
WORKDIR /mnt/lis-bio-sources
RUN --mount=type=cache,target=/home/intermine/.gradle \
  ./gradlew install; ./gradlew clean

COPY ./mine.properties /etc/

ENV PSQL_USER="postgres"
ENV PSQL_PWD="postgres"
ENV TOMCAT_USER="tomcat"
ENV TOMCAT_PWD="tomcat"

COPY --chmod=775 ./entrypoint.sh /usr/local/bin

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
