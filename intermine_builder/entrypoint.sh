#!/bin/sh

set -o errexit -o nounset -o xtrace

cd /home/intermine/intermine/${MINE_NAME}

sed -e "s/PSQL_USER/${PSQL_USER}/g" \
    -e "s/PSQL_PWD/${PSQL_PWD}/g" \
    -e "s/TOMCAT_USER/${TOMCAT_USER}/g" \
    -e "s/TOMCAT_PWD/${TOMCAT_PWD}/g" /etc/mine.properties > /home/intermine/.intermine/${MINE_NAME}.properties

cat <<END > /home/intermine/intermine/${MINE_NAME}/dbmodel/resources/objectstoresummary.config.properties
max.field.values = 200

# autocomplete = in forms on the webapp, these fields will offer suggestions to the user as they type
# index is created in post process create-autocomplete-index
autocomplete.solrurl = http://solr:8983/solr/${MINE_NAME}-autocomplete/

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

index.solrurl = http://solr:8983/solr/${MINE_NAME}-search/
index.batch.size = 1000
END

case ${1:-} in
  load) ./gradlew buildDB --stacktrace
        ./gradlew buildUserDB --stacktrace
        ./gradlew integrate --stacktrace
        ./gradlew postprocess --stacktrace ;;

     *) ./gradlew cargoDeployRemote
        # intermine/intermine issue #2162
        sleep 60
        ./gradlew cargoRedeployRemote  --stacktrace;;
esac
