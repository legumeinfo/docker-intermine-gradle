#!/bin/sh

set -o errexit -o nounset -o xtrace

cd /home/intermine/intermine/${MINE_NAME}

sed -e "s/PSQL_USER/${PSQL_USER}/g" \
    -e "s/PSQL_PWD/${PSQL_PWD}/g" \
    -e "s/TOMCAT_USER/${TOMCAT_USER}/g" \
    -e "s/TOMCAT_PWD/${TOMCAT_PWD}/g" /etc/mine.properties > /home/intermine/.intermine/${MINE_NAME}.properties

case ${1:-} in
  load) ./gradlew buildDB --stacktrace
        ./gradlew buildUserDB --stacktrace
        ./gradlew integrate --stacktrace
        ./gradlew postprocess --stacktrace ;;

     *) ./gradlew cargoDeployRemote
        sleep 60
        ./gradlew cargoRedeployRemote  --stacktrace;;
esac
