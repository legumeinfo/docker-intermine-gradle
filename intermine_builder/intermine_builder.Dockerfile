FROM alpine:3.20

ENV JAVA_HOME="/usr/lib/jvm/default-jvm"

RUN apk add --no-cache openjdk11

RUN apk add --no-cache git \
                       maven \
                       postgresql-client \
                       perl \
                       perl-utils

RUN apk add --no-cache build-base
RUN apk add --no-cache wget \
                        perl-app-cpanminus \
                        perl-module-build \
                        perl-module-build-tiny \
                        perl-module-find \
                        perl-package-stash \
                        perl-sub-identify \
                        perl-moose \
                        perl-moosex-types \
                        perl-datetime \
                        perl-html-parser \
                        perl-html-tree \
                        perl-io-gzip \
                        perl-libwww \
                        perl-libxml-perl \
                        perl-list-moreutils-xs \
                        perl-moosex \
                        perl-text-csv_xs \
                        perl-text-glob \
                        perl-uri \
                        perl-xml-dom \
                        perl-xml-libxml \
                        perl-xml-parser

RUN perl -MCPAN -e \
'my $c = "CPAN::HandleConfig"; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => "follow"); $c->edit(build_requires_install_policy => "yes"); $c->commit'

RUN cpanm --force Ouch \
                  Web::Scraper \
                  Number::Format \
                #   PerlIO::gzip \
                  Perl6::Junction \
                #   List::MoreUtils \
                #   Moose \
                #   MooseX::Role::WithOverloading \
                  MooseX::FollowPBP \
                  MooseX::ABC \
                  MooseX::FileAttribute \
                #   Text::CSV_XS \
                  XML::Parser::PerlSAX
                #  Getopt::Std \
                #  Digest::MD5 \
                #  Log::Handler

RUN mkdir /home/intermine && mkdir /home/intermine/intermine
RUN chmod -R 777 /home/intermine

ENV MEM_OPTS="-Xmx1g -Xms500m"
ENV GRADLE_OPTS="-server ${MEM_OPTS} -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99 -Dorg.gradle.daemon=false -Duser.home=/home/intermine"
ENV HOME="/home/intermine"
ENV USER_HOME="/home/intermine"
ENV GRADLE_USER_HOME="/home/intermine/.gradle"
ENV PSQL_USER="postgres"
ENV PSQL_PWD="postgres"
ENV TOMCAT_USER="tomcat"
ENV TOMCAT_PWD="tomcat"
ENV TOMCAT_PORT=8080
ENV PGPORT=5432

COPY ./build.sh /home/intermine
RUN chmod a+rx /home/intermine/build.sh
WORKDIR /home/intermine/intermine

CMD ["/bin/sh","/home/intermine/build.sh"]
