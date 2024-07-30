#!/usr/bin/env bash

# This script will create the various secrets needed by our installation. Before running set the following env variables

# HOSTP12   - The .p12 file corresponding to the host certificate
# ROBOTP12  - The .p12 file corresponding to the robot certificate 
# INSTANCE  - The instance name (dev/testbed/int/prod)
# UPDATE_HOST_CERTS - Set to 1 to update host certificates
# UPDATE_FTS_CERTS  - Set to 1 to update FTS certificates

# Function to create secrets from .p12 files
create_secrets_from_p12() {
    local p12_file=$1
    local cert_file=$2
    local key_file=$3
    local cert_name=$4
    local key_name=$5

    openssl pkcs12 -in "$p12_file" -clcerts -nokeys -out "$cert_file"
    openssl pkcs12 -in "$p12_file" -nocerts -nodes -out "$key_file"

    kubectl -n rucio create secret generic "$cert_name" --from-file="$cert_file" --dry-run=client --save-config -o yaml | kubectl apply -f -
    kubectl -n rucio create secret generic "$key_name" --from-file="$key_file" --dry-run=client --save-config -o yaml | kubectl apply -f -
}

# Update host certificates if required
if [ "${UPDATE_HOST_CERTS:-0}" -eq 1 ]; then
    create_secrets_from_p12 "$HOSTP12" "tls.crt" "tls.key" "hostcert" "hostkey"

    cp tls.crt hostcert.pem
    cp tls.key hostkey.pem
    kubectl -n rucio create secret tls host-tls-secret --key=tls.key --cert=tls.crt --dry-run=client --save-config -o yaml | kubectl apply -f -
    exit 0
fi

# Update FTS certificates if required
if [ "${UPDATE_FTS_CERTS:-0}" -eq 1 ]; then
    create_secrets_from_p12 "$ROBOTP12" "robotcert.pem" "robotkey.pem" "rootcert" "rootkey"
    exit 0
fi

# Create the namespace if it doesn't exist
kubectl create namespace rucio --dry-run=client -o yaml | kubectl apply -f -

# Extract certificates and keys from the .p12 files
echo "When prompted, enter the password used to encrypt the HOST P12 file"
openssl pkcs12 -in "$HOSTP12" -clcerts -nokeys -out tls.crt
openssl pkcs12 -in "$HOSTP12" -nocerts -nodes -out tls.key

cp tls.key hostkey.pem
cp tls.crt hostcert.pem

echo "When prompted, enter the password used to encrypt the ROBOT P12 file"
openssl pkcs12 -in "$ROBOTP12" -clcerts -nokeys -out robotcert.pem
openssl pkcs12 -in "$ROBOTP12" -nocerts -nodes -out robotkey.pem

# Create new secrets
echo "Creating new secrets"

kubectl -n rucio create secret tls host-tls-secret --key=tls.key --cert=tls.crt --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic rootcert --from-file=robotcert.pem --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic rootkey --from-file=robotkey.pem --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic hostcert --from-file=hostcert.pem --dry-run=client --save-config -o yaml | kubectl apply -f -
kubectl -n rucio create secret generic hostkey --from-file=hostkey.pem --dry-run=client --save-config -o yaml | kubectl apply -f -

# Clean up temporary files
rm tls.key tls.crt hostkey.pem hostcert.pem robotcert.pem robotkey.pem

# Create secrets from an environment file
kubectl -n rucio create secret generic rucio-secrets --from-env-file="${INSTANCE}-secrets.cfg" --dry-run=client --save-config -o yaml | kubectl apply -f -

# Display the created secrets
kubectl -n rucio get secrets
