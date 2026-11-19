#!/bin/bash
# Restores the BAG database from the dump mounted at /dump (pg_dump directory format). The postgres
# entrypoint runs this once, when the data directory is empty; a failure stops the container, the
# data directory then has to be emptied before the next attempt.
set -euo pipefail

DUMP=/dump
if [ ! -f "$DUMP/toc.dat" ]; then
  echo "restore.sh: no dump found in $DUMP (expected a pg_dump directory with toc.dat)" >&2
  exit 1
fi

psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS postgis"

echo "restore.sh: restoring $DUMP with ${RESTORE_JOBS:-4} jobs, this takes a while"
PGOPTIONS="-c maintenance_work_mem=1GB" pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  --jobs "${RESTORE_JOBS:-4}" --no-owner --no-privileges --exit-on-error "$DUMP"

psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "VACUUM ANALYZE"
echo "restore.sh: done"
