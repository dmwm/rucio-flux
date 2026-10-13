#!/usr/bin/env bash

# This script creates (or updates) the secrets needed by DMM (apps/options/dmm). Before running set the following env variables

# DMM_CFG          - dmm.cfg. Set [db] db_host=dmm-postgres and password=$DMM_DB_PASSWORD,
#                    and [fts] cert=/opt/certs/cert.pem key=/opt/certs/key.pem
# DMM_RUCIO_CFG    - rucio.cfg for DMM's Rucio client, pointing at this instance's server.
#                    The grid CAs are under /cvmfs/grid.cern.ch/etc/grid-security/certificates
# SENSE_AUTH       - .sense-o-auth.yaml with the SENSE-O credentials
# DMM_CERT         - Certificate DMM uses with FTS
# DMM_KEY          - Key for DMM_CERT
# DMM_DB_PASSWORD  - Password for DMM's PostgreSQL. Only takes effect when the database is first created

set -e

kubectl -n rucio create secret generic dmm-config --from-file=dmm.cfg=$DMM_CFG --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic dmm-rucio-config --from-file=rucio.cfg=$DMM_RUCIO_CFG --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic dmm-sense-config --from-file=.sense-o-auth.yaml=$SENSE_AUTH --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic dmm-certs --from-file=cert.pem=$DMM_CERT --from-file=key.pem=$DMM_KEY --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic dmm-db --from-literal=password=$DMM_DB_PASSWORD --dry-run=client --save-config -o yaml | kubectl apply -f -

# Secrets mounted with subPath are not refreshed in running pods
kubectl -n rucio rollout restart deployment dmm || true
