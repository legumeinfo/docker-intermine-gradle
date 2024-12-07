FROM docker.io/obolibrary/robot:v1.9.7 AS data
SHELL ["/bin/bash", "-o", "pipefail", "-euc"]

WORKDIR /data/crop-ontology
RUN for crop in 335 340; \
  do curl -Sf  https://cropontology.org/ontology/CO_${crop}/rdf \
     | robot convert --check false -i /dev/stdin --format obo -o /dev/stdout \
     | sed -e '/^name:/d' -e "s/CO:${crop}/CO_${crop}/g" > CO_${crop}.obo; done
WORKDIR /data/InterPro
RUN curl -Sf https://ftp.ebi.ac.uk/pub/databases/interpro/releases/103.0/interpro.xml.gz | gzip -dc > interpro.xml
WORKDIR /data/Pfam
RUN curl -Sf https://ftp.ebi.ac.uk/pub/databases/Pfam/releases/Pfam37.0/database_files/pfamA.txt.gz | gzip -d > pfamA.txt
WORKDIR /data/PANTHER
RUN curl -SfO http://data.pantherdb.org/ftp/hmm_classifications/19.0/PANTHER19.0_HMM_classifications
WORKDIR /data/SO-Ontologies/Ontology_Files
RUN curl -SfO https://raw.githubusercontent.com/The-Sequence-Ontology/SO-Ontologies/refs/heads/master/Ontology_Files/so-simple.obo 
WORKDIR /data/plant-ontology
RUN curl -SfO https://raw.githubusercontent.com/Planteome/plant-ontology/refs/heads/master/po.obo
WORKDIR /data/plant-trait-ontology
RUN curl -SfO https://raw.githubusercontent.com/Planteome/plant-trait-ontology/refs/heads/master/to.obo
WORKDIR /data/gene-ontology
RUN curl -SfO https://purl.obolibrary.org/obo/go/go-basic.obo
WORKDIR /data/InterPro/ontology
RUN curl -SfO https://ftp.ebi.ac.uk/pub/databases/GO/goa/external2go/interpro2go

FROM docker.io/library/maven:3-amazoncorretto-11-alpine AS mine

RUN mkdir -m 777 /home/intermine && mkdir -m 777 /home/intermine/intermine

# JDK_JAVA_OPTIONS
# override default MAVEN_CONFIG=/root/.m2 in maven base image
ENV MAVEN_CONFIG="/home/intermine/.m2"
ENV MEM_OPTS="-Xmx2g -Xms1g"
ENV GRADLE_OPTS="-server ${MEM_OPTS} -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99 -Dorg.gradle.daemon=false -Duser.home=/home/intermine"
ENV HOME="/home/intermine"
ENV USER_HOME="/home/intermine"
ENV GRADLE_USER_HOME="/home/intermine/.gradle"

SHELL ["/bin/sh", "-euc"]

# Build intermine
COPY ./intermine /home/intermine/.intermine
RUN cd /home/intermine/.intermine; \
  for dir in plugin intermine bio bio/sources bio/postprocess; \
  do \
    (cd ${dir} && ./gradlew install && ./gradlew clean) \
  done; \
  rm -rf /home/intermine/.gradle

# Build lis-bio-sources
COPY ./lis-bio-sources /mnt/lis-bio-sources
RUN cd /mnt/lis-bio-sources \
  && ./gradlew install \
  && ./gradlew clean \
  &&  rm -rf /home/intermine/.gradle

COPY ./mine.properties /etc/

ENV PSQL_USER="postgres"
ENV PSQL_PWD="postgres"
ENV TOMCAT_USER="tomcat"
ENV TOMCAT_PWD="tomcat"

COPY --chmod=775 ./entrypoint.sh /usr/local/bin

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

FROM mine AS load
COPY --link --from=data /data/ /home/intermine/data/