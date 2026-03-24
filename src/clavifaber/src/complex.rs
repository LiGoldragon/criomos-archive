use crate::error::Error;
use crate::util::atomic_write;
use base64ct::Encoding;
use ed25519_dalek::pkcs8::{DecodePrivateKey, EncodePrivateKey};
use ed25519_dalek::SigningKey;
use rand::rngs::OsRng;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::time::SystemTime;

/// The complex: a node's root Ed25519 identity.
/// Generated once at first install, root-owned.
///
/// Layout:
///   <dir>/key.pem       — PKCS#8 Ed25519 private key (0600)
///   <dir>/ssh.pub       — OpenSSH public key (0644)
pub struct Complex {
    pub signing_key: SigningKey,
}

impl Complex {
    /// Generate a new complex (fresh Ed25519 keypair).
    pub fn generate() -> Self {
        Self {
            signing_key: SigningKey::generate(&mut OsRng),
        }
    }

    /// Load an existing complex from its directory.
    pub fn load(dir: &Path) -> Result<Self, Error> {
        let key_path = dir.join("key.pem");
        let pem = fs::read_to_string(&key_path).map_err(|e| Error::Io {
            path: key_path.clone(),
            source: e,
        })?;
        let signing_key = SigningKey::from_pkcs8_pem(&pem)
            .map_err(|e| Error::Parse(format!("PKCS#8 decode {}: {e}", key_path.display())))?;
        Ok(Self { signing_key })
    }

    /// Write the complex to a directory. Atomic writes with restrictive permissions.
    pub fn write(&self, dir: &Path) -> Result<(), Error> {
        fs::create_dir_all(dir).map_err(|e| Error::Io {
            path: dir.to_path_buf(),
            source: e,
        })?;
        fs::set_permissions(dir, fs::Permissions::from_mode(0o700)).map_err(|e| Error::Io {
            path: dir.to_path_buf(),
            source: e,
        })?;

        // Write PKCS#8 private key (atomic)
        let pkcs8_doc = self
            .signing_key
            .to_pkcs8_der()
            .map_err(|e| Error::Parse(format!("PKCS#8 encode: {e}")))?;
        let key_pem = pkcs8_doc
            .to_pem("PRIVATE KEY", pem_rfc7468::LineEnding::LF)
            .map_err(|e| Error::Parse(format!("PEM encode: {e}")))?;
        atomic_write(&dir.join("key.pem"), key_pem.as_bytes(), 0o600)?;

        // Write SSH public key (atomic)
        let ssh_pub = self.ssh_pubkey_string();
        atomic_write(&dir.join("ssh.pub"), ssh_pub.as_bytes(), 0o644)?;

        Ok(())
    }

    /// Validate an existing complex. Returns:
    /// - Ok(Some(cx)) if key exists and parses correctly
    /// - Ok(None) if no key exists or key was corrupt (corrupt key renamed aside)
    /// - Err only on I/O failure during rename
    pub fn validate(dir: &Path) -> Result<Option<Self>, Error> {
        let key_path = dir.join("key.pem");
        if !key_path.exists() {
            return Ok(None);
        }
        match Self::load(dir) {
            Ok(cx) => Ok(Some(cx)),
            Err(e) => {
                let ts = SystemTime::now()
                    .duration_since(SystemTime::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs();
                let broken = dir.join(format!("key.pem.broken.{ts}"));
                fs::rename(&key_path, &broken).map_err(|source| Error::Corrupt {
                    path: key_path.clone(),
                    detail: format!("{e}; rename to {} failed: {source}", broken.display()),
                })?;
                eprintln!(
                    "warning: corrupt key renamed to {} ({e})",
                    broken.display()
                );
                let ssh_path = dir.join("ssh.pub");
                if ssh_path.exists() {
                    let _ = fs::rename(&ssh_path, dir.join(format!("ssh.pub.broken.{ts}")));
                }
                Ok(None)
            }
        }
    }

    /// Format the public key as an OpenSSH string.
    pub fn ssh_pubkey_string(&self) -> String {
        let vk = self.signing_key.verifying_key();
        let pk_bytes = vk.as_bytes();
        let key_type = b"ssh-ed25519";
        let mut blob = Vec::new();
        push_ssh_string(&mut blob, key_type);
        push_ssh_string(&mut blob, pk_bytes);
        let encoded = base64ct::Base64::encode_string(&blob);
        format!("ssh-ed25519 {encoded} complex")
    }
}

fn push_ssh_string(buf: &mut Vec<u8>, data: &[u8]) {
    buf.extend_from_slice(&(data.len() as u32).to_be_bytes());
    buf.extend_from_slice(data);
}
