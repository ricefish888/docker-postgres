FROM postgres:9.5.4

MAINTAINER Alexey Zhokhov <alexey@zhokhov.com>

VOLUME ["/var/lib/postgresql/data", "/var/log/postgresql"]

COPY docker-entrypoint.sh /
RUN chmod a+x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
