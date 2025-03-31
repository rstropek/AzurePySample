export PGHOST=psql-ulix73f47kgqg.postgres.database.azure.com
export PGUSER=db
export PGPORT=5432
export PGDATABASE=postgres
export PGPASSWORD="$(az account get-access-token --resource https://ossrdbms-aad.database.windows.net --query accessToken --output tsv)" 

psql
