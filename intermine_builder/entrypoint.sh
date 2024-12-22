#!/bin/sh

set -o errexit -o nounset -o xtrace

cd /home/intermine/intermine/${MINE_NAME}

sed -e "s/MINE_NAME/${MINE_NAME}/g" \
    -e "s/PGHOST/${PGHOST}/g" \
    -e "s/PGPORT/${PGPORT}/g" \
    -e "s/PGUSER/${PGUSER}/g" \
    -e "s/PGPASSWORD/${PGPASSWORD}/g" \
    -e "s/SOLR_HOST/${SOLR_HOST}/g" \
    -e "s/TOMCAT_HOST_PORT/${TOMCAT_HOST_PORT}/g" \
    -e "s/TOMCAT_USER/${TOMCAT_USER}/g" \
    -e "s/TOMCAT_PWD/${TOMCAT_PWD}/g" /etc/mine.properties > /home/intermine/.intermine/${MINE_NAME}.properties

cat <<END > /home/intermine/intermine/${MINE_NAME}/dbmodel/resources/objectstoresummary.config.properties
max.field.values = 200

# autocomplete = in forms on the webapp, these fields will offer suggestions to the user as they type
# index is created in post process create-autocomplete-index
autocomplete.solrurl = http://${SOLR_HOST}/solr/${MINE_NAME}-autocomplete/

org.intermine.model.bio.OntologyTerm.autocomplete = name
org.intermine.model.bio.SOTerm.autocomplete = name
END

cat <<END > /home/intermine/intermine/${MINE_NAME}/dbmodel/resources/keyword_search.properties
index.temp.directory = /tmp
index.references.BioEntity = synonyms crossReferences organism
index.references.OntologyTerm = synonyms
#index.references.Gene = pathways proteins.proteinDomains goAnnotation.ontologyTerm
#index.references.Protein = proteinDomains

index.ignore = Comment CrossReference Location OntologyAnnotation OntologyRelation Sequence Synonym

index.facet.single.Category = Category
index.facet.single.Organism = organism.shortName
#index.facet.multi.Pathway = pathways.name

index.boost.Gene = 1.5
index.boost.Protein = 1.2

search.debug = false

index.solrurl = http://${SOLR_HOST}/solr/${MINE_NAME}-search/
index.batch.size = 1000
END

if [ ${#} -gt 0 ]
then
  exec "$@" # run any manually-specified commands
elif [ -f /home/intermine/.gradle/${MINE_NAME}.done ]
then
  echo "${MINE_NAME} already built"
  exit 0;
else
  gradle buildDB --stacktrace
  gradle buildUserDB --stacktrace
  gradle integrate --stacktrace
  ## Run postprocesses individually to avoid postgres
  ## "FATAL: sorry, too many clients already" error
  ## intermine/intermine issue #1971
  #./gradlew postprocess --stacktrace
  for name in $(sed  -n '/post-process/s/.*name="\([^"]*\)".*/\1/p' project.xml)
  do
    gradle postprocess -Pprocess=${name} --stacktrace
  done

  gradle cargoDeployRemote
fi
