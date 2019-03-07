#!/bin/bash
set -e
#gcloud auth login
export KEYRING_NAME="spectra-vault"
export KEY_NAME="spectra-vault-init"
gcloud kms keyrings create ${KEYRING_NAME} --location global
gcloud kms keys create ${KEY_NAME} --location global --keyring ${KEYRING_NAME} --purpose encryption
export GOOGLE_PROJECT=$(gcloud config get-value project)
# This init's the Terraform variable file
cat - > terraform.tfvars <<EOF
project_id = "${GOOGLE_PROJECT}"
storage_bucket = "spectra-vault"
kms_keyring_name = "${KEYRING_NAME}"
EOF
#  Terraform is already installed under tools/
ln -s tools/terraform terraform
./terraform init
./terraform apply -auto-approve
gcloud compute ssh $(gcloud compute instances list --limit=1 --filter=name~vault- --uri) -- sudo bash
## everything below is done with root on the vault server
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=/etc/vault/vault-server.ca.crt.pem
export VAULT_CLIENT_CERT=/etc/vault/vault-server.crt.pem
export VAULT_CLIENT_KEY=/etc/vault/vault-server.key.pem
gcloud kms decrypt \
    --location=global  \
    --keyring=${KEYRING_NAME} \
    --key=${KEY_NAME} \
    --plaintext-file=/dev/stdout \
    --ciphertext-file=<(gsutil cat gs://spectra-vault-assets/vault_unseal_keys.txt.encrypted)
# manual part of doing
# vault unseal
# vault auth <root key>
# vault auth enable gcp
# vault write auth/gcp/config credentials="$(cat /etc/vault/gcp_credentials.json)" this will take care of allowing Vault to setup a backend with GCP
# Now we set up the KV secrets engine
# vault secrets enable -version=1 kv (this will have only strings as values, and won't be versioned)
# Then we set up the roles and policies in the /vault-setup folder
# Then we create the secret for MongoDB, to start
# In order to get a signed vault local token, run:
vault login -method=gcp \
    role="my-role" \
    service_account="authenticating-account@my-project.iam.gserviceaccounts.com" \
    project="my-project" \
    jwt_exp="15m"

