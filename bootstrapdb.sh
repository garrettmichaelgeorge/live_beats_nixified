#!/bin/bash

set -euxo pipefail

POSTGRES_DB="postgres"
POSTGRES_USER="postgres"

psql -v ON_ERROR_STOP=1 --host localhost --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE DATABASE live_beats_prod;
EOSQL
