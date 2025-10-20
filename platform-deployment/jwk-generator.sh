#!/usr/bin/env bash

# This script can generate a JWT for testing purposes.
# On first run it will also generate a private and public key
# AND corresponding JWKS that are production ready
# Originally from https://gist.github.com/shu-yusa/213901a5a0902de5ad3f62a61036f4ce

## REQUIRES openssl, nodejs, jq
## FIXES for jwt.io compliance
# use base64Url encoding
# use echo -n in pack function

# TODO for some reason the jwt token created by the script doesn't go through stack jwt verify

header='
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "api-key"
}'
payload='
{
  "iss": "confidentialmind.com",
  "sub": "123456789",
  "apikey": "ba2c25ba-7ea3-4f48-857a-c123b38fabc6",
  "exp": 1727078864
}'

function pack() {
  # Remove line breaks and spaces
  echo $1 | sed -e "s/[\r\n]\+//g" | sed -e "s/ //g"
}

function base64url_encode {
  (if [ -z "$1" ]; then cat -; else echo -n "$1"; fi) |
    openssl base64 -e -A |
      sed s/\\+/-/g |
      sed s/\\//_/g |
      sed -E s/=+$//
}

# just for debugging
function base64url_decode {
  INPUT=$(if [ -z "$1" ]; then echo -n $(cat -); else echo -n "$1"; fi)
  MOD=$(($(echo -n "$INPUT" | wc -c) % 4))
  PADDING=$(if [ $MOD -eq 2 ]; then echo -n '=='; elif [ $MOD -eq 3 ]; then echo -n '=' ; fi)
  echo -n "$INPUT$PADDING" |
    sed s/-/+/g |
    sed s/_/\\//g |
    openssl base64 -d -A
}

if [ ! -f private-key.pem ]; then
  # Private and Public keys
  openssl genpkey -algorithm RSA -out private-key.pem -pkeyopt rsa_keygen_bits:2048
  openssl rsa -in private-key.pem -pubout -out public-key.pem
fi

# Base64 Encoding
b64_header=$(pack "$header" | base64url_encode)
b64_payload=$(pack "$payload" | base64url_encode)
signature=$(echo -n $b64_header.$b64_payload | openssl dgst -sha256 -sign private-key.pem | base64url_encode)
# Export JWT
echo $b64_header.$b64_payload.$signature > jwt.txt
# Create JWK from public key
jwk=$(npx pem-jwk public-key.pem)
# Add additional fields
jwk=$(echo '{"use":"sig"}' $jwk $header | jq -cs add)
# Export JWK
echo '{"keys":['$jwk']}'| jq . > jwks.json

echo "--- JWT ---"
cat jwt.txt
echo -e "\n--- JWK ---"
jq . jwks.json
