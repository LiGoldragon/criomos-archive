use ssh_key::public::KeyData;
use spki::SubjectPublicKeyInfoOwned;
use der::asn1::{BitString, ObjectIdentifier};

/// OID for Ed25519: 1.3.101.112
const ED25519_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.3.101.112");

/// Parse an OpenSSH public key string and convert to SubjectPublicKeyInfo.
/// Accepts either the full "ssh-ed25519 AAAA..." format or just the base64 part.
pub fn ssh_pubkey_to_spki(ssh_pubkey_str: &str) -> Result<SubjectPublicKeyInfoOwned, String> {
    let pubkey = ssh_key::PublicKey::from_openssh(ssh_pubkey_str)
        .or_else(|_| {
            // Try parsing as just the key type + base64
            let full = if ssh_pubkey_str.contains(' ') {
                ssh_pubkey_str.to_string()
            } else {
                format!("ssh-ed25519 {ssh_pubkey_str}")
            };
            ssh_key::PublicKey::from_openssh(&full)
        })
        .map_err(|e| format!("invalid SSH public key: {e}"))?;

    match pubkey.key_data() {
        KeyData::Ed25519(ed_key) => {
            let raw_bytes = ed_key.as_ref();
            let spki = SubjectPublicKeyInfoOwned {
                algorithm: spki::AlgorithmIdentifierOwned {
                    oid: ED25519_OID,
                    parameters: None,
                },
                subject_public_key: BitString::from_bytes(raw_bytes)
                    .map_err(|e| format!("BitString encoding failed: {e}"))?,
            };
            Ok(spki)
        }
        _ => Err("only Ed25519 SSH keys are supported".into()),
    }
}

/// Get the raw Ed25519 public key bytes from an SSH public key string.
pub fn ssh_pubkey_raw_bytes(ssh_pubkey_str: &str) -> Result<Vec<u8>, String> {
    let pubkey = ssh_key::PublicKey::from_openssh(ssh_pubkey_str)
        .or_else(|_| {
            let full = if ssh_pubkey_str.contains(' ') {
                ssh_pubkey_str.to_string()
            } else {
                format!("ssh-ed25519 {ssh_pubkey_str}")
            };
            ssh_key::PublicKey::from_openssh(&full)
        })
        .map_err(|e| format!("invalid SSH public key: {e}"))?;

    match pubkey.key_data() {
        KeyData::Ed25519(ed_key) => Ok(ed_key.as_ref().to_vec()),
        _ => Err("only Ed25519 SSH keys are supported".into()),
    }
}

