.SHELLFLAGS = -o errexit -o nounset -o pipefail -c

.DELETE_ON_ERROR:
.ONESHELL:
.PHONY: down load postgres solr tomcat up

CONTAINERS = /project/legume_project/containers
DATASTORE = /project/legume_project/datastore/v2

# container images
ROBOT = apptainer exec $(CONTAINERS)/robot_v1.9.7.sif robot


include .env
export MINE_NAME
export APPTAINER_COMPAT := true
export APPTAINER_ENV_FILE := ${PWD}/.env
WORKDIR := ${TMPDIR}/intermine
DATADIR = $(WORKDIR)/intermine_builder/scratch/home/intermine/data

${DATADIR}/crop-ontology/CO_335.obo \
${DATADIR}/crop-ontology/CO_340.obo:
	mkdir -p ${@D}
	cd ${@D}
	crop=$(@F:.obo=)
	curl -LSf  https://cropontology.org/ontology/CO_$${crop}/rdf | \
      $(ROBOT) convert --check false -i /dev/stdin --format obo -o /dev/stdout | \
        sed -e '/^name:/d' -e "s/CO:$${crop}/CO_$${crop}/g" > $${crop}.obo

${DATADIR}/InterPro/interpro.xml:
	mkdir -p $(@D)
	curl -LSf https://ftp.ebi.ac.uk/pub/databases/interpro/releases/103.0/interpro.xml.gz | gzip -dc > $@

${DATADIR}/InterPro/ontology/interpro2go:
	mkdir -p $(@D)
	curl -LSf https://ftp.ebi.ac.uk/pub/databases/GO/goa/external2go/interpro2go > $@

${DATADIR}/Pfam/pfamA.txt:
	mkdir -p $(@D)
	curl -LSf https://ftp.ebi.ac.uk/pub/databases/Pfam/releases/Pfam37.0/database_files/pfamA.txt.gz | gzip -d > $@

${DATADIR}/PANTHER/PANTHER19.0_HMM_classifications:
	mkdir -p $(@D)
	curl -LSf http://data.pantherdb.org/ftp/hmm_classifications/19.0/PANTHER19.0_HMM_classifications > $@

${DATADIR}/SO-Ontologies/Ontology_Files/so-simple.obo:
	mkdir -p $(@D)
	curl -LSf https://raw.githubusercontent.com/The-Sequence-Ontology/SO-Ontologies/refs/heads/master/Ontology_Files/so-simple.obo > $@

${DATADIR}/plant-ontology/po.obo:
	mkdir -p $(@D)
	curl -LSf https://raw.githubusercontent.com/Planteome/plant-ontology/refs/heads/master/po.obo | grep -v '^import:' > $@

${DATADIR}/plant-trait-ontology/to.obo:
	mkdir -p $(@D)
	curl -LSf https://raw.githubusercontent.com/Planteome/plant-trait-ontology/refs/heads/master/to.obo | \
	  sed -e '/^import:/d' -e '/creation_date: [0-9-]\{10\}$$/s/$$/T00:00:00Z/' > $@

${DATADIR}/gene-ontology/go-basic.obo:
	mkdir -p $(@D)
	curl -LSf https://purl.obolibrary.org/obo/go/go-basic.obo > $@

data: \
${DATADIR}/crop-ontology/CO_335.obo \
${DATADIR}/crop-ontology/CO_340.obo \
${DATADIR}/InterPro/interpro.xml \
${DATADIR}/InterPro/ontology/interpro2go \
${DATADIR}/Pfam/pfamA.txt \
${DATADIR}/PANTHER/PANTHER19.0_HMM_classifications \
${DATADIR}/SO-Ontologies/Ontology_Files/so-simple.obo \
${DATADIR}/plant-ontology/po.obo \
${DATADIR}/plant-trait-ontology/to.obo \
${DATADIR}/gene-ontology/go-basic.obo \

$(WORKDIR)/build.done:
	export APPTAINER_WORKDIR=$(WORKDIR)/intermine_builder
	mkdir -p $${APPTAINER_WORKDIR}
	rsync -a --mkpath --delete ./intermine_builder/intermine/ $${APPTAINER_WORKDIR}/scratch/home/intermine/.intermine
	rsync -a --mkpath --delete ./intermine_builder/lis-bio-sources/ $${APPTAINER_WORKDIR}/scratch/home/intermine/lis-bio-sources
	apptainer exec \
	  --home /home/intermine \
	  --scratch /home/intermine \
	  $(CONTAINERS)/maven_3-amazoncorretto-11-alpine.sif sh -eux <<"END"
	  cd ~/.intermine
	  for dir in plugin intermine bio bio/sources bio/postprocess
	  do
	    (cd $${dir} && ./gradlew install && ./gradlew clean)
	  done
	  cd ~/lis-bio-sources
	  ./gradlew install
	END
	touch $@

build: $(WORKDIR)/build.done

up: postgres solr tomcat

postgres:
	export APPTAINER_WORKDIR=$(WORKDIR)/postgres
	mkdir -p $${APPTAINER_WORKDIR}
	apptainer instance run \
	  --bind ./postgres/init_postgresql.sql:/docker-entrypoint-initdb.d/init_postgresql.sql:ro \
	  --bind ./postgres/postgresql.conf:/opt/postgresql.conf:ro \
	  --scratch /var/lib/postgresql/data,/var/run/postgresql \
	  --env PGDATA=/var/lib/postgresql/data/pgdata \
	  --env POSTGRES_INITDB_ARGS='--auth-local=password --encoding=SQL_ASCII --lc-collate=C --lc-ctype=C' \
	  $(CONTAINERS)/postgres_17.2-alpine3.21.sif postgres \
	      -c config_file=/opt/postgresql.conf \
	      -c checkpoint_timeout=120min \
	      -c fsync=off \
	      -c full_page_writes=on \
	      -c listen_addresses=127.0.0.1 \
	      -c max_wal_senders=0 \
	      -c max_wal_size=64GB \
	      -c wal_compression=zstd \
	      -c wal_level=minimal

solr:
	export APPTAINER_WORKDIR=$(WORKDIR)/solr
	mkdir -p $${APPTAINER_WORKDIR}
	apptainer instance run \
	  --bind ./solr/scripts/intermine.sh:/opt/scripts/intermine.sh:ro \
	  --env JAVA_OPTS='-Xmx2g -Xms1g -Dorg.apache.el.parser.SKIP_IDENTIFIER_CHECK=true -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99' \
 	  --env SOLR_IP_ALLOWLIST='127.0.0.1, [::1]' \
	  --scratch /var/solr \
	  $(CONTAINERS)/solr_8.11-slim.sif solr /opt/scripts/intermine.sh ${MINE_NAME}


tomcat:
	export APPTAINER_WORKDIR=$(WORKDIR)/tomcat
	mkdir -p $${APPTAINER_WORKDIR}
	apptainer exec \
	  --scratch /usr/local/tomcat/webapps \
	  $(CONTAINERS)/tomcat_8-jre11-temurin-jammy.sif sh -c 'ln -sf $${CATALINA_HOME}/webapps.dist/* $${CATALINA_HOME}/webapps'
	
	apptainer instance run \
	  --bind ./tomcat/configs/context.xml:/usr/local/tomcat/conf/context.xml:ro \
	  --bind ./tomcat/configs/server.xml:/usr/local/tomcat/conf/server.xml:ro \
	  --bind ./tomcat/configs/tomcat-users.xml:/usr/local/tomcat/conf/tomcat-users.xml:ro \
	  --bind ./tomcat/configs/web_context.xml:/usr/local/tomcat/webapps.dist/manager/META-INF/tomcat-users.xml:ro \
	  --env JAVA_OPTS='-Xmx2g -Xms1g -Dorg.apache.el.parser.SKIP_IDENTIFIER_CHECK=true -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99' \
	  --scratch /usr/local/tomcat/webapps \
	  --scratch /usr/local/tomcat/logs \
	  --scratch /usr/local/tomcat/temp \
	  --scratch /usr/local/tomcat/work/Catalina/localhost \
	  $(CONTAINERS)/tomcat_8-jre11-temurin-jammy.sif tomcat

load: build data
	export APPTAINER_WORKDIR=$(WORKDIR)/intermine_builder
	rsync -a --mkpath --delete ./intermine_builder/${MINE_NAME} $${APPTAINER_WORKDIR}/scratch/home/intermine/intermine/
	mkdir -p $${APPTAINER_WORKDIR}/scratch/home/intermine/data/data-store/
	apptainer exec \
	  --home /home/intermine \
	  --scratch /home/intermine \
	  --bind $(DATASTORE):/home/intermine/data/data-store:ro \
	  --bind ./intermine_builder/mine.properties:/etc/mine.properties:ro \
	  --bind ./intermine_builder/entrypoint.sh:/usr/local/bin/entrypoint.sh \
	  $(CONTAINERS)/maven_3-amazoncorretto-11-alpine.sif /usr/local/bin/entrypoint.sh

down:
	apptainer instance stop postgres
	apptainer instance stop solr
	apptainer instance stop tomcat