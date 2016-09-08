#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
    set -- postgres "$@"
fi

if [ "$1" = 'postgres' ]; then
    mkdir -p "$PGDATA"
    chmod 700 "$PGDATA"
    chown -R postgres "$PGDATA"

    chmod g+s /run/postgresql
    chown -R postgres /run/postgresql

    # look specifically for PG_VERSION, as it is expected in the DB dir
    if [ ! -s "$PGDATA/PG_VERSION" ]; then
        eval "gosu postgres initdb $POSTGRES_INITDB_ARGS"

        # check password first so we can output the warning before postgres
        # messes it up
        if [ "$POSTGRES_PASSWORD" ]; then
            pass="PASSWORD '$POSTGRES_PASSWORD'"
            authMethod=md5
        else
            cat << EOWARN
                ****************************************************
                WARNING: No password has been set for the database.
                         This will allow anyone with access to the
                         Postgres port to access your database. In
                         Docker's default configuration, this is
                         effectively any other container on the same
                         system.

                         Use "-e POSTGRES_PASSWORD=password" to set
                         it in "docker run".
                ****************************************************
EOWARN

            pass=
            authMethod=trust
        fi

        { echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA/pg_hba.conf"

        # internal start of server in order to allow set-up using psql-client       
        # does not listen on external TCP/IP and waits until start finishes
        gosu postgres pg_ctl -D "$PGDATA" \
            -o "-c listen_addresses='localhost'" \
            -w start

        : ${POSTGRES_USER:=postgres}
        : ${POSTGRES_DB:=$POSTGRES_USER}
        export POSTGRES_USER POSTGRES_DB

        psql=( psql -v ON_ERROR_STOP=1 )

        if [ "$POSTGRES_DB" != 'postgres' ]; then
            "${psql[@]}" --username postgres << EOSQL
                CREATE DATABASE "$POSTGRES_DB" ;
EOSQL
            echo
        fi

        if [ "$POSTGRES_USER" = 'postgres' ]; then
            op='ALTER'
        else
            op='CREATE'
        fi
        "${psql[@]}" --username postgres << EOSQL
            $op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
EOSQL
        echo

        psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

        echo
        for f in /docker-entrypoint-initdb.d/*; do
            case "$f" in
                *.sh)     echo "$0: running $f"; . "$f" ;;
                *.sql)    echo "$0: running $f"; "${psql[@]}" < "$f"; echo ;;
                *.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
                *)        echo "$0: ignoring $f" ;;
            esac
            echo
        done

        gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

        echo
        echo 'PostgreSQL init process complete; ready for start up.'
        echo
    fi

MY_CPU_COUNT=$(nproc)
MY_MEMORY_SIZE=$(cat /proc/meminfo | grep MemTotal | awk '{ print $2 }')
MY_MEMORY_GB=$(awk "BEGIN { rounded = sprintf(\"%.0f\", $MY_MEMORY_SIZE / 1000000); print rounded }")

if [ -z "$MAX_CONNECTIONS" ]; then
    MAX_CONNECTIONS=300;
fi

if [ -z "$EFFECTIVE_CACHE_SIZE" ]; then
    EFFECTIVE_CACHE_SIZE=$(($MY_MEMORY_GB /2 ));

    if [ "$EFFECTIVE_CACHE_SIZE" -eq "0" ]; then
        EFFECTIVE_CACHE_SIZE=1;
    fi
fi

if [ -z "$SHARED_BUFFERS" ]; then
    SHARED_BUFFERS=$(($MY_MEMORY_GB / 4 ));

    if [ "$SHARED_BUFFERS" -eq "0" ]; then
        SHARED_BUFFERS=1;
    fi
fi

echo "CPU COUNT: ${MY_CPU_COUNT}"
echo "MEMORY SIZE: ${MY_MEMORY_GB}GB"
echo "MAX CONNECTIONS: ${MAX_CONNECTIONS}"
echo "EFFECTIVE_CACHE_SIZE: ${EFFECTIVE_CACHE_SIZE}GB"
echo "SHARED_BUFFERS: ${SHARED_BUFFERS}GB"

# Configure logs
#sed -i -e"s/^#logging_collector = off.*$/logging_collector = on/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_directory = 'pg_log'.*$/log_directory = '\/var\/log\/postgresql'/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_filename = 'postgresql-\%Y-\%m-\%d_\%H\%M\%S.log'.*$/log_filename = 'postgresql_\%a.log'/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_file_mode = 0600.*$/log_file_mode = 0644/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_truncate_on_rotation = off.*$/log_truncate_on_rotation = on/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_rotation_age = 1d.*$/log_rotation_age = 1d/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_min_duration_statement = -1.*$/log_min_duration_statement = 0/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_checkpoints = off.*$/log_checkpoints = on/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_connections = off.*$/log_connections = on/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_disconnections = off.*$/log_disconnections = on/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^log_line_prefix = '\%t \[\%p-\%l\] \%q\%u@\%d '.*$/log_line_prefix = '\%t \[\%p\]: \[\%l-1\] user=\%u,db=\%d'/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_lock_waits = off.*$/log_lock_waits = on/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#log_temp_files = -1.*$/log_temp_files = 0/" /var/lib/postgresql/data/postgresql.conf

# Performance Tuning
sed -i -e"s/^max_connections = 100.*$/max_connections = $MAX_CONNECTIONS/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^shared_buffers =.*$/shared_buffers = ${SHARED_BUFFERS}GB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#effective_cache_size = 4GB.*$/effective_cache_size = ${EFFECTIVE_CACHE_SIZE}GB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#work_mem = 4MB.*$/work_mem = 16MB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#maintenance_work_mem = 64MB.*$/maintenance_work_mem = 2GB/" /var/lib/postgresql/data/postgresql.conf
#sed -i -e"s/^#checkpoint_segments = .*$/checkpoint_segments = 32/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#checkpoint_completion_target = 0.5.*$/checkpoint_completion_target = 0.7/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#wal_buffers =.*$/wal_buffers = 16MB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#default_statistics_target = 100.*$/default_statistics_target = 100/" /var/lib/postgresql/data/postgresql.conf

    exec gosu postgres "$@"
fi

exec "$@"
