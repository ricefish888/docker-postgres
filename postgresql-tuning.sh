#!/usr/bin/env bash
set -e

MY_CPU_COUNT=$(cat /proc/cpuinfo | grep processor | wc -l)
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

echo "Tuning config:"
echo "  Processors count: ${MY_CPU_COUNT}"
echo "  Total memory: ${MY_MEMORY_GB}GB"
echo "  max_connections: ${MAX_CONNECTIONS}"
echo "  effective_cache_size: ${EFFECTIVE_CACHE_SIZE}GB"
echo "  shared_buffers: ${SHARED_BUFFERS}GB"
echo ""

# Performance Tuning
sed -i -e"s/^max_connections = 100.*$/max_connections = $MAX_CONNECTIONS/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^shared_buffers =.*$/shared_buffers = ${SHARED_BUFFERS}GB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#effective_cache_size = 4GB.*$/effective_cache_size = ${EFFECTIVE_CACHE_SIZE}GB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#work_mem = 4MB.*$/work_mem = 16MB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#maintenance_work_mem = 64MB.*$/maintenance_work_mem = 2GB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#checkpoint_completion_target = 0.5.*$/checkpoint_completion_target = 0.7/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#wal_buffers =.*$/wal_buffers = 16MB/" /var/lib/postgresql/data/postgresql.conf
sed -i -e"s/^#default_statistics_target = 100.*$/default_statistics_target = 100/" /var/lib/postgresql/data/postgresql.conf
