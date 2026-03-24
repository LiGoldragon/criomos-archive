mod complex;
mod error;
mod gpg_agent;
mod ssh_key;
mod util;
mod x509;

use clap::{Parser, Subcommand};
use error::Error;
use std::fs;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "clavifaber", about = "GPG → X.509 certificate tool for CriomOS WiFi PKI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a self-signed CA certificate from a GPG Ed25519 key
    CaInit {
        #[arg(long)]
        keygrip: String,
        #[arg(long)]
        cn: String,
        #[arg(long)]
        out: PathBuf,
    },

    /// Generate a P-256 server keypair + certificate signed by the CA
    ServerCert {
        #[arg(long)]
        ca_keygrip: String,
        #[arg(long)]
        ca_cert: PathBuf,
        #[arg(long)]
        cn: String,
        #[arg(long)]
        out_cert: PathBuf,
        #[arg(long)]
        out_key: PathBuf,
    },

    /// Create an X.509 client certificate for a node's Ed25519 SSH pubkey
    NodeCert {
        #[arg(long)]
        ca_keygrip: String,
        #[arg(long)]
        ca_cert: PathBuf,
        #[arg(long)]
        ssh_pubkey: String,
        #[arg(long)]
        cn: String,
        #[arg(long)]
        out: PathBuf,
    },

    /// Generate node identity complex (Ed25519 keypair) at first install
    ComplexInit {
        #[arg(long)]
        dir: PathBuf,
    },

    /// Re-derive ssh.pub from the private key (run on every boot)
    DerivePubkey {
        #[arg(long)]
        dir: PathBuf,
    },

    /// Verify a certificate chains to the CA
    Verify {
        #[arg(long)]
        ca_cert: PathBuf,
        #[arg(long)]
        cert: PathBuf,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::CaInit { keygrip, cn, out } => cmd_ca_init(&keygrip, &cn, &out),
        Commands::ServerCert {
            ca_keygrip,
            ca_cert,
            cn,
            out_cert,
            out_key,
        } => cmd_server_cert(&ca_keygrip, &ca_cert, &cn, &out_cert, &out_key),
        Commands::NodeCert {
            ca_keygrip,
            ca_cert,
            ssh_pubkey,
            cn,
            out,
        } => cmd_node_cert(&ca_keygrip, &ca_cert, &ssh_pubkey, &cn, &out),
        Commands::ComplexInit { dir } => cmd_complex_init(&dir),
        Commands::DerivePubkey { dir } => cmd_derive_pubkey(&dir),
        Commands::Verify { ca_cert, cert } => cmd_verify(&ca_cert, &cert),
    };

    if let Err(e) = result {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

fn cmd_ca_init(keygrip: &str, cn: &str, out: &PathBuf) -> Result<(), Error> {
    eprintln!("Creating CA certificate: CN={cn}");

    let pubkey_bytes = export_ed25519_pubkey_from_keygrip(keygrip)?;

    let spki = spki::SubjectPublicKeyInfoOwned {
        algorithm: spki::AlgorithmIdentifierOwned {
            oid: der::asn1::ObjectIdentifier::new_unwrap("1.3.101.112"),
            parameters: None,
        },
        subject_public_key: der::asn1::BitString::from_bytes(&pubkey_bytes)
            .map_err(|e| Error::Certificate(format!("BitString: {e}")))?,
    };

    let cert_der = x509::create_ca_cert(keygrip, cn, spki)?;
    let pem = x509::cert_to_pem(&cert_der)?;

    fs::write(out, &pem).map_err(|e| Error::Io {
        path: out.clone(),
        source: e,
    })?;
    eprintln!("CA certificate written to {}", out.display());
    Ok(())
}

fn cmd_server_cert(
    ca_keygrip: &str,
    ca_cert_path: &PathBuf,
    cn: &str,
    out_cert: &PathBuf,
    out_key: &PathBuf,
) -> Result<(), Error> {
    eprintln!("Creating server certificate: CN={cn}");

    let ca_pem = fs::read_to_string(ca_cert_path).map_err(|e| Error::Io {
        path: ca_cert_path.clone(),
        source: e,
    })?;
    let ca_der = x509::pem_to_cert_der(&ca_pem)?;

    let (cert_der, key_pem) = x509::create_server_cert(ca_keygrip, &ca_der, cn)?;
    let cert_pem = x509::cert_to_pem(&cert_der)?;

    fs::write(out_cert, &cert_pem).map_err(|e| Error::Io {
        path: out_cert.clone(),
        source: e,
    })?;
    fs::write(out_key, &key_pem).map_err(|e| Error::Io {
        path: out_key.clone(),
        source: e,
    })?;

    eprintln!("Server certificate: {}", out_cert.display());
    eprintln!("Server private key: {}", out_key.display());
    Ok(())
}

fn cmd_node_cert(
    ca_keygrip: &str,
    ca_cert_path: &PathBuf,
    ssh_pubkey_str: &str,
    cn: &str,
    out: &PathBuf,
) -> Result<(), Error> {
    eprintln!("Creating node certificate: CN={cn}");

    let ca_pem = fs::read_to_string(ca_cert_path).map_err(|e| Error::Io {
        path: ca_cert_path.clone(),
        source: e,
    })?;
    let ca_der = x509::pem_to_cert_der(&ca_pem)?;

    let spki = ssh_key::ssh_pubkey_to_spki(ssh_pubkey_str)?;
    let cert_der = x509::create_node_cert(ca_keygrip, &ca_der, spki, cn)?;
    let pem = x509::cert_to_pem(&cert_der)?;

    fs::write(out, &pem).map_err(|e| Error::Io {
        path: out.clone(),
        source: e,
    })?;
    eprintln!("Node certificate written to {}", out.display());
    Ok(())
}

fn cmd_complex_init(dir: &PathBuf) -> Result<(), Error> {
    match complex::Complex::validate(dir)? {
        Some(existing) => {
            let ssh_pub = existing.ssh_pubkey_string();
            eprintln!("complex already exists at {}", dir.display());
            println!("{ssh_pub}");
        }
        None => {
            eprintln!("Generating node identity complex at {}", dir.display());
            let cx = complex::Complex::generate();
            cx.write(dir)?;
            let ssh_pub = cx.ssh_pubkey_string();
            eprintln!("Complex generated. SSH public key:");
            println!("{ssh_pub}");
        }
    }
    Ok(())
}

fn cmd_derive_pubkey(dir: &PathBuf) -> Result<(), Error> {
    let cx = complex::Complex::load(dir)?;
    let ssh_pub = cx.ssh_pubkey_string();
    let ssh_path = dir.join("ssh.pub");
    util::atomic_write(&ssh_path, ssh_pub.as_bytes(), 0o644)?;
    println!("{ssh_pub}");
    Ok(())
}

fn cmd_verify(ca_cert_path: &PathBuf, cert_path: &PathBuf) -> Result<(), Error> {
    let ca_pem = fs::read_to_string(ca_cert_path).map_err(|e| Error::Io {
        path: ca_cert_path.clone(),
        source: e,
    })?;
    let cert_pem = fs::read_to_string(cert_path).map_err(|e| Error::Io {
        path: cert_path.clone(),
        source: e,
    })?;

    let ca_der = x509::pem_to_cert_der(&ca_pem)?;
    let cert_der = x509::pem_to_cert_der(&cert_pem)?;

    x509::verify_cert_chain(&ca_der, &cert_der)?;
    eprintln!("OK: certificate chains to CA");
    Ok(())
}

/// Extract Ed25519 public key bytes from GPG via keygrip.
/// Tries `gpg --export-ssh-key` first, falls back to READKEY via agent.
fn export_ed25519_pubkey_from_keygrip(keygrip: &str) -> Result<Vec<u8>, Error> {
    let output = std::process::Command::new("gpg")
        .args(["--batch", "--export-ssh-key", &format!("{keygrip}!")])
        .output()
        .map_err(|e| Error::Gpg(format!("gpg --export-ssh-key: {e}")))?;

    if output.status.success() {
        let ssh_line = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !ssh_line.is_empty() {
            return ssh_key::ssh_pubkey_raw_bytes(&ssh_line);
        }
    }

    let mut agent = gpg_agent::GpgAgent::connect()?;
    agent.readkey(keygrip)
}
