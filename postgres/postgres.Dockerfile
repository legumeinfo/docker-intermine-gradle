FROM postgres:17-alpine

COPY ./init_postgresql.sh /docker-entrypoint-initdb.d/
COPY ./postgresql.conf /opt/postgresql.conf

CMD ["postgres", "-c", "config_file=/opt/postgresql.conf"]
