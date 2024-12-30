.SHELLFLAGS = -o errexit -o nounset -o pipefail -c

.DELETE_ON_ERROR:
.ONESHELL:
.PHONY: down build postgres solr tomcat up

# container images
CONTAINERS = /project/legume_project/containers

# https://wave.seqera.io/view/builds/bd-fd45f4a88e38da89_1
# gradle 5.6.4, openjdk 11.0.25
INTERMINE_BUILDER_IMAGE = $(CONTAINERS)/gradle_openjdk_fd45f4a88e38da89.sif
INTERMINE_LOADER_IMAGE = $(CONTAINERS)/gradle_openjdk_fd45f4a88e38da89.sif
POSTGRES_IMAGE = $(CONTAINERS)/postgres_17.2-alpine3.21.sif 
ROBOT_IMAGE = $(CONTAINERS)/robot_v1.9.7.sif
SOLR_IMAGE = $(CONTAINERS)/solr_9.7-slim.sif
TOMCAT_IMAGE = $(CONTAINERS)/tomcat_9-jre17-temurin-noble.sif

DATASTORE = /project/legume_project/datastore/v2

include .env
export MINE_NAME
export APPTAINER_COMPAT := true
export APPTAINER_ENV_FILE := ${PWD}/.env
WORKDIR := ${TMPDIR}/${MINE_NAME}
DATADIR = $(WORKDIR)/intermine_builder/scratch/home/intermine/data

${DATADIR}/crop-ontology/CO_335.obo \
${DATADIR}/crop-ontology/CO_336.obo \
${DATADIR}/crop-ontology/CO_340.obo:
	mkdir -p ${@D}
	cd ${@D}
	crop=$(@F:.obo=)
	curl -LSf  https://cropontology.org/ontology/CO_$${crop}/rdf | \
      apptainer exec $(ROBOT_IMAGE) robot convert --check false -i /dev/stdin --format obo -o /dev/stdout | \
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

common-data: \
${DATADIR}/InterPro/interpro.xml \
${DATADIR}/InterPro/ontology/interpro2go \
${DATADIR}/Pfam/pfamA.txt \
${DATADIR}/PANTHER/PANTHER19.0_HMM_classifications \
${DATADIR}/SO-Ontologies/Ontology_Files/so-simple.obo \
${DATADIR}/plant-ontology/po.obo \
${DATADIR}/plant-trait-ontology/to.obo \
${DATADIR}/gene-ontology/go-basic.obo \

minimine-data: common-data \
               ${DATADIR}/crop-ontology/CO_335.obo \
               ${DATADIR}/crop-ontology/CO_340.obo

glycinemine-data: common-data \
                  ${DATADIR}/crop-ontology/CO_336.obo

data: $(MINE_NAME)-data

$(WORKDIR)/intermine_builder/compile.done:
	export APPTAINER_WORKDIR=$(WORKDIR)/intermine_builder
	mkdir -p $${APPTAINER_WORKDIR}
	rsync -a --mkpath --delete ./intermine_builder/intermine/ $${APPTAINER_WORKDIR}/scratch/home/intermine/.intermine
	rsync -a --mkpath --delete ./intermine_builder/lis-bio-sources/ $${APPTAINER_WORKDIR}/scratch/home/intermine/lis-bio-sources
	apptainer exec \
	  --home /home/intermine \
	  --scratch /home/intermine \
	  $(INTERMINE_BUILDER_IMAGE) sh -eux <<"END"
	  cd ~/.intermine
	  for dir in plugin intermine bio bio/sources bio/postprocess
	  do
	    echo "BUILDING: $$dir"
	    (cd $${dir} && gradle install && gradle clean)
	  done
	  cd ~/lis-bio-sources
	  gradle install
	END
	touch $@

build: $(WORKDIR)/intermine_builder/compile.done

up: postgres solr tomcat

postgres:
	if [ $$(apptainer instance list "$${MINE_NAME}-postgres" | wc -l) -gt 1 ]
	then
	  echo "$${MINE_NAME}-postgres already started; skipping..." 1>&2
	  exit 0
	fi
	export APPTAINER_WORKDIR=$(WORKDIR)/postgres
	mkdir -p $${APPTAINER_WORKDIR}
	apptainer instance run \
	  --bind ./postgres/init_postgresql.sql:/docker-entrypoint-initdb.d/init_postgresql.sql:ro \
	  --bind ./postgres/postgresql.conf:/opt/postgresql.conf:ro \
	  --scratch /var/lib/postgresql/data,/var/run/postgresql \
	  --env PGDATA=/var/lib/postgresql/data/pgdata \
	  --env POSTGRES_INITDB_ARGS='--auth-local=password --encoding=SQL_ASCII --lc-collate=C --lc-ctype=C' \
	  $(POSTGRES_IMAGE) $${MINE_NAME}-postgres \
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
	if [ $$(apptainer instance list "$${MINE_NAME}-solr" | wc -l) -gt 1 ]
	then
	  echo "$${MINE_NAME}-postgres already started; skipping..." 1>&2
	  exit 0
	fi
	export APPTAINER_WORKDIR=$(WORKDIR)/solr
	mkdir -p $${APPTAINER_WORKDIR}
	apptainer instance run \
	  --bind ./solr/scripts/intermine.sh:/docker-entrypoint-initdb.d/intermine.sh:ro \
	  --env JAVA_OPTS='-Xmx2g -Xms1g -Dorg.apache.el.parser.SKIP_IDENTIFIER_CHECK=true -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99' \
 	  --env SOLR_IP_ALLOWLIST='127.0.0.1, [::1]' \
	  --scratch /var/solr \
	  $(SOLR_IMAGE) $${MINE_NAME}-solr


tomcat:
	if [ $$(apptainer instance list "$${MINE_NAME}-tomcat" | wc -l) -gt 1 ]
	then
	  echo "$${MINE_NAME}-tomcat already started; skipping..." 1>&2
	  exit 0
	fi
	export APPTAINER_WORKDIR=$(WORKDIR)/tomcat
	mkdir -p $${APPTAINER_WORKDIR}
	apptainer exec \
	  --scratch /usr/local/tomcat/webapps \
	  $(TOMCAT_IMAGE) sh -c 'ln -sf $${CATALINA_HOME}/webapps.dist/* $${CATALINA_HOME}/webapps'
	
	apptainer instance run \
	  --bind ./tomcat/configs/context.xml:/usr/local/tomcat/conf/context.xml:ro \
	  --bind ./tomcat/configs/server.xml:/usr/local/tomcat/conf/server.xml:ro \
	  --bind ./tomcat/configs/tomcat-users.xml:/usr/local/tomcat/conf/tomcat-users.xml:ro \
	  --bind ./tomcat/configs/web_context.xml:/usr/local/tomcat/webapps.dist/manager/META-INF/context.xml:ro \
	  --env JAVA_OPTS='-Xmx2g -Xms1g -Dorg.apache.el.parser.SKIP_IDENTIFIER_CHECK=true -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99' \
	  --scratch /usr/local/tomcat/webapps \
	  --scratch /usr/local/tomcat/logs \
	  --scratch /usr/local/tomcat/temp \
	  --scratch /usr/local/tomcat/work/Catalina/localhost \
	  $(TOMCAT_IMAGE) $${MINE_NAME}-tomcat

build: compile data up
	export APPTAINER_WORKDIR=$(WORKDIR)/intermine_builder
	rsync -a --mkpath --delete ./mines/${MINE_NAME} $${APPTAINER_WORKDIR}/scratch/home/intermine/intermine/
	mkdir -p $${APPTAINER_WORKDIR}/scratch/home/intermine/data/data-store/
	apptainer exec \
	  --home /home/intermine \
	  --scratch /home/intermine \
	  --bind $(DATASTORE):/home/intermine/data/data-store:ro \
	  --bind ./intermine_builder/mine.properties:/etc/mine.properties:ro \
	  --bind ./intermine_builder/entrypoint.sh:/usr/local/bin/entrypoint.sh \
	  $(INTERMINE_LOADER_IMAGE) /usr/local/bin/entrypoint.sh

down:
	if [ $$(apptainer instance list "$${MINE_NAME}-*" | wc -l) -gt 1 ]
	then
	  apptainer instance stop "$${MINE_NAME}-*"
	fi

# Remove postgres, solr, and tomcat data,
# leaving output of "data" and "compile" targets.
# Used before rerunning "make up; make build".
cleanbuild: down
	rm -rf $(WORKDIR)/postgres $(WORKDIR)/solr $(WORKDIR)/tomcat

cleancompile: mostlyclean
	rm -rf $(WORKDIR)/intermine_builder/compile.done 
	find $(WORKDIR)/intermine_builder/scratch/home/intermine -mindepth 1 -maxdepth 1 ! -name data -exec rm -rf {} +

# Delete data as well
clean: down
	rm -rf ${WORKDIR}
