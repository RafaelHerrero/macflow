#!/usr/bin/env bash
#
# Cria um certificado self-signed de "Code Signing" no seu chaveiro de login,
# chamado "macflow-codesign". O install.sh usa esse certificado para assinar o
# binário de forma ESTÁVEL — assim a permissão de Acessibilidade sobrevive a
# recompilações (sem re-prompt a cada build).
#
# Rode UMA vez:  ./scripts/create-codesign-cert.sh
# É idempotente: se o certificado já existir, não faz nada.
set -euo pipefail

CERT="macflow-codesign"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

say() { printf "\033[1;34m▸\033[0m %s\n" "$1"; }

if security find-certificate -c "$CERT" >/dev/null 2>&1; then
    say "Certificado '$CERT' já existe. Nada a fazer."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Gerando certificado self-signed de code signing…"
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

# O `security import` da Apple só lê PKCS12 no formato antigo. Por isso:
#   -legacy       → encriptação/MAC PBE-SHA1-3DES (não o SHA-256 do OpenSSL 3)
#   -macalg sha1  → MAC em SHA-1 (o SHA-256 padrão causa "MAC verification failed")
#   senha real    → senha vazia + MAC também quebra o import; usamos uma temporária.
P12_PW="macflow-import"
openssl pkcs12 -export -legacy -macalg sha1 -out "$TMP/cert.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$CERT" -passout pass:"$P12_PW" >/dev/null 2>&1

say "Importando no chaveiro de login (autorizando o codesign a usá-lo)…"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$P12_PW" -T /usr/bin/codesign >/dev/null

# Evita o diálogo "codesign quer usar a chave" liberando a partition list.
# Pede a senha do seu login (a do chaveiro). Falha aqui não é fatal: no máximo
# o macOS pedirá "Sempre Permitir" na primeira assinatura.
say "Liberando acesso à chave (pode pedir a senha do seu login)…"
read -r -s -p "Senha de login (Enter p/ pular): " LOGIN_PW; echo
if [[ -n "${LOGIN_PW:-}" ]]; then
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
        -s -k "$LOGIN_PW" "$KEYCHAIN" >/dev/null 2>&1 \
        && say "Acesso liberado." \
        || say "Não consegui liberar automaticamente (não é fatal)."
fi

say "Pronto! Certificado '$CERT' criado."
echo
echo "  Próximo passo: rode ./install.sh novamente para reassinar com ele."
echo "  Depois, conceda a Acessibilidade UMA vez — e ela passa a persistir."
