use crate::error::Error;
use der::asn1::{BitString, ObjectIdentifier};
use spki::SubjectPublicKeyInfoOwned;
use ssh_key::public::KeyData;

const ED25519_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.3.101.112");

/// Parse an OpenSSH public key string and convert to SubjectPublicKeyInfo.
pub fn ssh_pubkey_to_spki(ssh_pubkey_str: &str) -> Result<SubjectPublicKeyInfoOwned, Error> {
    let pubkey = parse_ssh_pubkey(ssh_pubkey_str)?;
    match pubkey.key_data() {
        KeyData::Ed25519(ed_key) => {
            let spki = SubjectPublicKeyInfoOwned {
                algorithm: spki::AlgorithmIdentifierOwned {
                    oid: ED25519_OID,
                    parameters: None,
                },
                subject_public_key: BitString::from_bytes(ed_key.as_ref())
                    .map_err(|e| Error::Parse(format!("BitString: {e}")))?,
            };
            Ok(spki)
        }
        _ => Err(Error::Parse("only Ed25519 SSH keys are supported".into())),
    }
}

/// Get the raw Ed25519 public key bytes from an SSH public key string.
pub fn ssh_pubkey_raw_bytes(ssh_pubkey_str: &str) -> Result<Vec<u8>, Error> {
    let pubkey = parse_ssh_pubkey(ssh_pubkey_str)?;
    match pubkey.key_data() {
        KeyData::Ed25519(ed_key) => Ok(ed_key.as_ref().to_vec()),
        _ => Err(Error::Parse("only Ed25519 SSH keys are supported".into())),
    }
}

fn parse_ssh_pubkey(s: &str) -> Result<ssh_key::PublicKey, Error> {
    ssh_key::PublicKey::from_openssh(s)
        .or_else(|_| {
            let full = if s.contains(' ') {
                s.to_string()
            } else {
                format!("ssh-ed25519 {s}")
            };
            ssh_key::PublicKey::from_openssh(&full)
        })
        .map_err(|e| Error::Parse(format!("invalid SSH public key: {e}")))
}
