#!/usr/bin/env bash

# This script will create the various secrets needed by our installation. Before running set the following env variables

# HOSTP12   - The .p12 file corresponding to the host certificate
# ROBOTP12  - The .p12 file corresponding to the robot certificate 
# INSTANCE  - The instance name (dev/testbed/int/prod)

export DAEMON_NAME=daemons
export SERVER_NAME=server
export UI_NAME=webui
export GLOBUS_NAME=cms-globus
export LOADTEST_NAME=loadtest-daemons

echo
echo "When prompted, enter the password used to encrypt the HOST P12 file"

# Setup files so that secrets are unavailable the least amount of time

openssl pkcs12 -in $HOSTP12 -clcerts -nokeys -out ./tls.crt
openssl pkcs12 -in $HOSTP12 -nocerts -nodes -out ./tls.key
# Secrets for the auth server
cp tls.key hostkey.pem
cp tls.crt hostcert.pem
cp /etc/pki/tls/certs/CERN_Root_CA.pem ca.pem
chmod 600 ca.pem


echo
echo "When prompted, enter the password used to encrypt the ROBOT P12 file"

openssl pkcs12 -in $ROBOTP12 -clcerts -nokeys -out usercert.pem
openssl pkcs12 -in $ROBOTP12 -nocerts -nodes -out new_userkey.pem

export ROBOTCERT=usercert.pem
export ROBOTKEY=new_userkey.pem


kubectl create namespace rucio

# Many of these are old names. Change as we slowly adopt the new names everywhere.

echo "Removing existing secrets"

kubectl -n rucio delete secret rucio-server.tls-secret
kubectl -n rucio delete secret ${DAEMON_NAME}-fts-cert ${DAEMON_NAME}-fts-key ${DAEMON_NAME}-hermes-cert ${DAEMON_NAME}-hermes-key 
kubectl -n rucio delete secret ${LOADTEST_NAME}-fts-cert ${LOADTEST_NAME}-fts-key
kubectl -n rucio delete secret ${DAEMON_NAME}-rucio-ca-bundle ${DAEMON_NAME}-rucio-ca-bundle-reaper
kubectl -n rucio delete secret ${GLOBUS_NAME}-rucio-ca-bundle ${GLOBUS_NAME}-rucio-ca-bundle-reaper
kubectl -n rucio delete secret ${LOADTEST_NAME}-rucio-ca-bundle ${LOADTEST_NAME}-rucio-ca-bundle-reaper
kubectl -n rucio delete secret ${SERVER_NAME}-rucio-ca-bundle 
kubectl -n rucio delete secret ${SERVER_NAME}-hostcert ${SERVER_NAME}-hostkey ${SERVER_NAME}-cafile  
kubectl -n rucio delete secret ${SERVER_NAME}-auth-hostcert ${SERVER_NAME}-auth-hostkey ${SERVER_NAME}-auth-cafile  
kubectl -n rucio delete secret ${UI_NAME}-hostcert ${UI_NAME}-hostkey ${UI_NAME}-cafile 
kubectl -n rucio delete secret ${LOADTEST_NAME}-rucio-x509up

# cms-ruciod-prod-rucio-x509up is created by the FTS key generator

echo "Creating new secrets"
kubectl -n rucio create secret tls rucio-server.tls-secret --key=tls.key --cert=tls.crt

kubectl -n rucio create secret generic ${SERVER_NAME}-hostcert --from-file=hostcert.pem
kubectl -n rucio create secret generic ${SERVER_NAME}-hostkey --from-file=hostkey.pem
kubectl -n rucio create secret generic ${SERVER_NAME}-cafile  --from-file=ca.pem

kubectl -n rucio create secret generic ${SERVER_NAME}-auth-hostcert --from-file=hostcert.pem
kubectl -n rucio create secret generic ${SERVER_NAME}-auth-hostkey --from-file=hostkey.pem
kubectl -n rucio create secret generic ${SERVER_NAME}-auth-cafile  --from-file=ca.pem

# Make secrets for WEBUI
# We don't make the CA file here, but lower because it is different than the regular server

export UI_NAME=webui
kubectl create -n rucio secret generic ${UI_NAME}-hostcert --from-file=hostcert.pem
kubectl create -n rucio secret generic ${UI_NAME}-hostkey --from-file=hostkey.pem

# Secrets for FTS, hermes

kubectl -n rucio create secret generic ${DAEMON_NAME}-fts-cert --from-file=$ROBOTCERT
kubectl -n rucio create secret generic ${DAEMON_NAME}-fts-key --from-file=$ROBOTKEY
kubectl -n rucio create secret generic ${LOADTEST_NAME}-fts-cert --from-file=$ROBOTCERT
kubectl -n rucio create secret generic ${LOADTEST_NAME}-fts-key --from-file=$ROBOTKEY
kubectl -n rucio create secret generic ${DAEMON_NAME}-hermes-cert --from-file=$ROBOTCERT
kubectl -n rucio create secret generic ${DAEMON_NAME}-hermes-key --from-file=$ROBOTKEY
kubectl -n rucio create secret generic ${DAEMON_NAME}-rucio-ca-bundle --from-file=/etc/pki/tls/certs/CERN-bundle.pem

# Secrets for Globus
kubectl -n rucio create secret generic ${GLOBUS_NAME}-rucio-ca-bundle --from-file=/etc/pki/tls/certs/CERN-bundle.pem
kubectl -n rucio delete secret ${GLOBUS_NAME}-rucio-x509up
kubectl -n rucio create secret generic ${GLOBUS_NAME}-rucio-x509up  --from-file=/etc/pki/tls/certs/CERN-bundle.pem # This is a dummy, but needed for container to start

# Secrets for Load test
kubectl create -n rucio secret generic ${LOADTEST_NAME}-rucio-ca-bundle --from-file=/etc/pki/tls/certs/CERN-bundle.pem
kubectl create -n rucio secret generic ${LOADTEST_NAME}-rucio-x509up  --from-file=/etc/pki/tls/certs/CERN-bundle.pem # This is a dummy, but needed for container to start

# More secrets for server
kubectl create -n rucio secret generic ${SERVER_NAME}-rucio-ca-bundle --from-file=/etc/pki/tls/certs/CERN-bundle.pem
kubectl create -n rucio secret generic ${SERVER_NAME}-rucio-x509up  --from-file=/etc/pki/tls/certs/CERN-bundle.pem # This is a dummy, but needed for container to start
kubectl create -n rucio secret generic ${DAEMON_NAME}-rucio-x509up  --from-file=/etc/pki/tls/certs/CERN-bundle.pem # This is a dummy, but needed for container to start

# WebUI needs whole bundle as ca.pem. Keep this at end since we just over-wrote ca.pem

cp /etc/pki/tls/certs/CERN-bundle.pem ca.pem  
kubectl -n rucio create secret generic ${UI_NAME}-cafile  --from-file=ca.pem

# Clean up
rm tls.key tls.crt hostkey.pem hostcert.pem ca.pem
rm usercert.pem new_userkey.pem

# Reapers needs the whole directory of certificates
mkdir /tmp/reaper-certs
cp /etc/grid-security/certificates/*.0 /tmp/reaper-certs/
cp /etc/grid-security/certificates/*.signing_policy /tmp/reaper-certs/
kubectl -n rucio create secret generic ${DAEMON_NAME}-rucio-ca-bundle-reaper --from-file=/tmp/reaper-certs/
kubectl -n rucio create secret generic ${GLOBUS_NAME}-rucio-ca-bundle-reaper --from-file=/tmp/reaper-certs/
rm -rf /tmp/reaper-certs

kubectl -n rucio create secret generic rucio-secrets --from-env-file=${INSTANCE}-secrets.yaml

kubectl -n rucio get secrets
