#!/usr/bin/env bash
#
# Creates a self-signed "Code Signing" certificate in your login keychain,
# named "macflow-codesign". install.sh uses this certificate to sign the
# binary in a STABLE way — so the Accessibility permission survives rebuilds
# (no re-prompt on every build).
#
# Run ONCE:  ./scripts/create-codesign-cert.sh
# It is idempotent: if the certificate already exists, it does nothing.
set -euo pipefail

CERT="macflow-codesign"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

say() { printf "\033[1;34m▸\033[0m %s\n" "$1"; }

if security find-certificate -c "$CERT" >/dev/null 2>&1; then
    say "Certificate '$CERT' already exists. Nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Generating self-signed code signing certificate…"
cat > "$TMP/cert.conf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[ dn ]
CN = $CERT
[ v3 ]
keyUsage         = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -config "$TMP/cert.conf" >/dev/null 2>&1

# Apple's `security import` only reads PKCS12 in the legacy format. Hence:
#   -legacy       → PBE-SHA1-3DES encryption/MAC (not OpenSSL 3's SHA-256)
#   -macalg sha1  → SHA-1 MAC (the default SHA-256 causes "MAC verification failed")
#   real password → an empty password + MAC also breaks the import; we use a temporary one.
P12_PW="macflow-import"
openssl pkcs12 -export -legacy -macalg sha1 -out "$TMP/cert.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$CERT" -passout pass:"$P12_PW" >/dev/null 2>&1

say "Importing into the login keychain (authorizing codesign to use it)…"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$P12_PW" -T /usr/bin/codesign >/dev/null

# Avoids the "codesign wants to use the key" dialog by opening the partition list.
# Asks for your login password (the keychain one). Failure here is not fatal: at
# worst macOS will ask "Always Allow" on the first signing.
say "Opening access to the key (may ask for your login password)…"
read -r -s -p "Login password (Enter to skip): " LOGIN_PW; echo
if [[ -n "${LOGIN_PW:-}" ]]; then
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
        -s -k "$LOGIN_PW" "$KEYCHAIN" >/dev/null 2>&1 \
        && say "Access opened." \
        || say "Could not open it automatically (not fatal)."
fi

say "Done! Certificate '$CERT' created."
echo
echo "  Next step: run ./install.sh again to re-sign with it."
echo "  Then grant Accessibility ONCE — and it will persist."
