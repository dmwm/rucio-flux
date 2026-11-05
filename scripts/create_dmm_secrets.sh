#!/usr/bin/env bash

# This script creates (or updates) the secrets needed by DMM (apps/options/dmm). Run it on a host with
# /etc/grid-security/certificates (lxplus, for instance). Before running set the following env variables

# DMM_CFG          - dmm.cfg. Set [db] db_host=dmm-postgres and password=$DMM_DB_PASSWORD,
#                    and [fts] cert=/opt/proxy/x509up key=/opt/proxy/x509up (the daemons' proxy, server-rucio-x509up)
# DMM_RUCIO_CFG    - rucio.cfg for DMM's Rucio client, pointing at this instance's server.
#                    The grid CAs are mounted at /etc/grid-security/certificates
# SENSE_AUTH       - .sense-o-auth.yaml with the SENSE-O credentials
# DMM_DB_PASSWORD  - Password for DMM's PostgreSQL. Only takes effect when the database is first created

set -e

kubectl -n rucio create secret generic dmm-config --from-file=dmm.cfg=$DMM_CFG --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic dmm-rucio-config --from-file=rucio.cfg=$DMM_RUCIO_CFG --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic dmm-sense-config --from-file=.sense-o-auth.yaml=$SENSE_AUTH --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic dmm-db --from-literal=password=$DMM_DB_PASSWORD --dry-run=client --save-config -o yaml | kubectl apply -f -

# DMM verifies FTS against a CA directory, which needs the hashed file names, not a bundle.
# Applied server side: a client side apply would copy it into an annotation, which is too big
mkdir /tmp/dmm-certs
cp /etc/grid-security/certificates/*.0 /tmp/dmm-certs/
kubectl -n rucio create secret generic dmm-grid-certificates --from-file=/tmp/dmm-certs/ --dry-run=client -o yaml | kubectl apply --server-side --force-conflicts -f -
rm -rf /tmp/dmm-certs

# Secrets mounted with subPath are not refreshed in running pods
kubectl -n rucio rollout restart deployment dmm || true
