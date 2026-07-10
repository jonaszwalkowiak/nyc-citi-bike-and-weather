#!/usr/bin/env bash
# Generate an RSA key pair for Snowflake key-pair auth.
#   - private key -> ./secrets/dbt_user.p8  (mounted read-only into the containers)
#   - public key  -> printed, ready to paste into snowflake/_SNOWFLAKE.sql
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p secrets

KEY_FILE="secrets/dbt_user.p8"

if [[ -f "$KEY_FILE" ]]; then
  echo "WARNING: $KEY_FILE already exists. Remove it first if you want a fresh key." >&2
  exit 1
fi

# Unencrypted PKCS#8 private key (no passphrase -> simplest for automation)
openssl genrsa 2048 2>/dev/null \
  | openssl pkcs8 -topk8 -inform PEM -nocrypt -out "$KEY_FILE"
chmod 600 "$KEY_FILE"

# Public key in the exact single-line form Snowflake wants (no PEM header/footer)
PUB=$(openssl rsa -in "$KEY_FILE" -pubout 2>/dev/null | sed '1d;$d' | tr -d '\n')

echo
echo "Private key written to $KEY_FILE"
echo
echo "Now paste this into snowflake/_SNOWFLAKE.sql   (RSA_PUBLIC_KEY = '...'):"
echo
echo "$PUB"
echo
