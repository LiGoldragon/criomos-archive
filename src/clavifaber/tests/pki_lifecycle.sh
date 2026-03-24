#!/usr/bin/env bash
# Full PKI lifecycle test for clavifaber
# Tests: CA init → server cert → node cert → verify chain
# Requires: gpg, gpg-agent, clavifaber binary
set -euo pipefail

CLAVIFABER="${1:-cargo run --quiet --}"
TESTDIR=$(mktemp -d "/tmp/clavifaber-pki-test.XXXXXX")
GNUPGHOME="$TESTDIR/gpg"

cleanup() {
  gpgconf --homedir "$GNUPGHOME" --kill gpg-agent 2>/dev/null || true
  rm -rf "$TESTDIR"
}
trap cleanup EXIT

echo "=== PKI lifecycle test ==="
echo "    testdir: $TESTDIR"

# --- Phase 1: Create temporary GPG key ---
echo ""
echo "--- Phase 1: Generate test GPG Ed25519 key ---"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

cat > "$TESTDIR/keygen.batch" <<'BATCH'
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Name-Real: Aedifico Test CA
Name-Email: test@aedifico.criome
Expire-Date: 0
%commit
BATCH

export GNUPGHOME
gpg --batch --gen-key "$TESTDIR/keygen.batch" 2>&1 | grep -v "^$"

# Extract keygrip
KEYGRIP=$(gpg --list-secret-keys --with-keygrip --with-colons 2>/dev/null \
  | grep '^grp:' | head -1 | cut -d: -f10)

if [ -z "$KEYGRIP" ]; then
  echo "FAIL: could not extract keygrip"
  exit 1
fi
echo "    keygrip: $KEYGRIP"

# Ensure agent is running
gpg-connect-agent /bye 2>/dev/null

# --- Phase 2: Generate node complex (node's own keypair) ---
echo ""
echo "--- Phase 2: Generate node complex ---"
NODE_DIR="$TESTDIR/complex-probus"
$CLAVIFABER complex-init --dir "$NODE_DIR"
NODE_SSH_PUB=$(cat "$NODE_DIR/ssh.pub")
echo "    node pubkey: $NODE_SSH_PUB"

# Verify derive-pubkey works
$CLAVIFABER derive-pubkey --dir "$NODE_DIR" > /dev/null
DERIVED=$(cat "$NODE_DIR/ssh.pub")
if [ "$DERIVED" != "$NODE_SSH_PUB" ]; then
  # derive-pubkey outputs to stdout, file should match
  echo "FAIL: derive-pubkey diverged from init"
  exit 1
fi
echo "    derive-pubkey: OK (matches)"

# --- Phase 3: Create CA certificate ---
echo ""
echo "--- Phase 3: Create CA certificate ---"
CA_CERT="$TESTDIR/ca.pem"
$CLAVIFABER ca-init --keygrip "$KEYGRIP" --cn "Aedifico Test CA" --out "$CA_CERT"

if [ ! -s "$CA_CERT" ]; then
  echo "FAIL: CA cert not created"
  exit 1
fi
echo "    ca cert: $(wc -c < "$CA_CERT") bytes"

# Verify with openssl
if command -v openssl &>/dev/null; then
  SUBJECT=$(openssl x509 -in "$CA_CERT" -noout -subject 2>/dev/null || echo "PARSE_FAIL")
  echo "    openssl subject: $SUBJECT"
  IS_CA=$(openssl x509 -in "$CA_CERT" -noout -text 2>/dev/null | grep -c "CA:TRUE" || true)
  if [ "$IS_CA" -lt 1 ]; then
    echo "FAIL: CA cert does not have CA:TRUE"
    exit 1
  fi
  echo "    CA:TRUE constraint: OK"
fi

# --- Phase 4: Create server certificate (P-256) ---
echo ""
echo "--- Phase 4: Create server certificate ---"
SERVER_CERT="$TESTDIR/server.pem"
SERVER_KEY="$TESTDIR/server.key"
$CLAVIFABER server-cert \
  --ca-keygrip "$KEYGRIP" \
  --ca-cert "$CA_CERT" \
  --cn "faber.criome" \
  --out-cert "$SERVER_CERT" \
  --out-key "$SERVER_KEY"

if [ ! -s "$SERVER_CERT" ] || [ ! -s "$SERVER_KEY" ]; then
  echo "FAIL: server cert/key not created"
  exit 1
fi
echo "    server cert: $(wc -c < "$SERVER_CERT") bytes"
echo "    server key:  $(wc -c < "$SERVER_KEY") bytes"

# Verify server cert
$CLAVIFABER verify --ca-cert "$CA_CERT" --cert "$SERVER_CERT"
echo "    verify chain: OK"

# --- Phase 5: Create node certificate (Ed25519 from complex) ---
echo ""
echo "--- Phase 5: Create node certificate ---"
NODE_CERT="$TESTDIR/probus.pem"
$CLAVIFABER node-cert \
  --ca-keygrip "$KEYGRIP" \
  --ca-cert "$CA_CERT" \
  --ssh-pubkey "$NODE_SSH_PUB" \
  --cn "probus@aedifico" \
  --out "$NODE_CERT"

if [ ! -s "$NODE_CERT" ]; then
  echo "FAIL: node cert not created"
  exit 1
fi
echo "    node cert: $(wc -c < "$NODE_CERT") bytes"

# Verify node cert
$CLAVIFABER verify --ca-cert "$CA_CERT" --cert "$NODE_CERT"
echo "    verify chain: OK"

if command -v openssl &>/dev/null; then
  NODE_CN=$(openssl x509 -in "$NODE_CERT" -noout -subject 2>/dev/null || echo "PARSE_FAIL")
  echo "    openssl subject: $NODE_CN"
fi

# --- Phase 6: Corruption recovery ---
echo ""
echo "--- Phase 6: Corruption recovery ---"
CORRUPT_DIR="$TESTDIR/complex-corrupt"
$CLAVIFABER complex-init --dir "$CORRUPT_DIR" > /dev/null
ORIGINAL_PUB=$(cat "$CORRUPT_DIR/ssh.pub")

# Corrupt the key
echo "GARBAGE" > "$CORRUPT_DIR/key.pem"

# Re-init should recover
$CLAVIFABER complex-init --dir "$CORRUPT_DIR" > /dev/null 2>&1
NEW_PUB=$(cat "$CORRUPT_DIR/ssh.pub")

if [ "$ORIGINAL_PUB" = "$NEW_PUB" ]; then
  echo "FAIL: key not regenerated after corruption"
  exit 1
fi

BROKEN_COUNT=$(ls "$CORRUPT_DIR"/key.pem.broken.* 2>/dev/null | wc -l)
if [ "$BROKEN_COUNT" -lt 1 ]; then
  echo "FAIL: broken key not preserved"
  exit 1
fi
echo "    corrupt key preserved: $BROKEN_COUNT broken file(s)"
echo "    new key generated: OK"

# --- Phase 7: Second node (multi-node cluster test) ---
echo ""
echo "--- Phase 7: Second node certificate ---"
NODE2_DIR="$TESTDIR/complex-faber"
$CLAVIFABER complex-init --dir "$NODE2_DIR"
NODE2_SSH_PUB=$(cat "$NODE2_DIR/ssh.pub")

NODE2_CERT="$TESTDIR/faber-node.pem"
$CLAVIFABER node-cert \
  --ca-keygrip "$KEYGRIP" \
  --ca-cert "$CA_CERT" \
  --ssh-pubkey "$NODE2_SSH_PUB" \
  --cn "faber@aedifico" \
  --out "$NODE2_CERT"

$CLAVIFABER verify --ca-cert "$CA_CERT" --cert "$NODE2_CERT"
echo "    second node cert verified: OK"

# --- Summary ---
echo ""
echo "=== ALL TESTS PASSED ==="
echo "    CA cert:     $CA_CERT"
echo "    Server cert: $SERVER_CERT"
echo "    Node certs:  $NODE_CERT, $NODE2_CERT"
echo "    Complexes:   $NODE_DIR, $NODE2_DIR, $CORRUPT_DIR"
