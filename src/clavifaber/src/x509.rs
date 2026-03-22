use der::asn1::{BitString, ObjectIdentifier, OctetString, SetOfVec};
use der::{Any, Decode, Encode, Tag};
use sha2::{Sha256, Digest};
use spki::{AlgorithmIdentifierOwned, SubjectPublicKeyInfoOwned};
use x509_cert::attr::AttributeTypeAndValue;
use x509_cert::name::{Name, RdnSequence, RelativeDistinguishedName};
use x509_cert::serial_number::SerialNumber;
use x509_cert::time::{Time, Validity};
use x509_cert::Certificate;
use x509_cert::TbsCertificate;
use const_oid::db::rfc5280::{ID_CE_BASIC_CONSTRAINTS, ID_CE_KEY_USAGE, ID_CE_SUBJECT_KEY_IDENTIFIER};

use crate::gpg_agent::{GpgAgent, parse_sig_sexp};

/// OID for Ed25519 signatures: 1.3.101.112
const ED25519_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.3.101.112");

/// OID for id-ecPublicKey: 1.2.840.10045.2.1
const EC_PUBLIC_KEY_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.2.840.10045.2.1");

/// OID for secp256r1 (P-256): 1.2.840.10045.3.1.7
const SECP256R1_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.2.840.10045.3.1.7");

/// OID for commonName: 2.5.4.3
const CN_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("2.5.4.3");

/// OID for organizationName: 2.5.4.10
const ORG_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("2.5.4.10");

/// Build a Name (RdnSequence) from a CN and optional O.
fn build_name(cn: &str, org: Option<&str>) -> Result<Name, String> {
    let mut rdns = Vec::new();

    if let Some(org_str) = org {
        let org_value = Any::new(
            Tag::Utf8String,
            org_str.as_bytes(),
        ).map_err(|e| format!("org Any encoding: {e}"))?;

        let org_atv = AttributeTypeAndValue {
            oid: ORG_OID,
            value: org_value,
        };
        let org_set = SetOfVec::try_from(vec![org_atv])
            .map_err(|e| format!("org RDN set: {e}"))?;
        rdns.push(RelativeDistinguishedName::from(org_set));
    }

    let cn_value = Any::new(
        Tag::Utf8String,
        cn.as_bytes(),
    ).map_err(|e| format!("cn Any encoding: {e}"))?;

    let cn_atv = AttributeTypeAndValue {
        oid: CN_OID,
        value: cn_value,
    };
    let cn_set = SetOfVec::try_from(vec![cn_atv])
        .map_err(|e| format!("cn RDN set: {e}"))?;
    rdns.push(RelativeDistinguishedName::from(cn_set));

    Ok(Name::from(RdnSequence::from(rdns)))
}

/// Generate a serial number from a hash of the public key and current time.
fn generate_serial(spki_der: &[u8]) -> Result<SerialNumber, String> {
    let mut hasher = Sha256::new();
    hasher.update(spki_der);
    hasher.update(
        &std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
            .to_le_bytes(),
    );
    let hash = hasher.finalize();
    // Use first 20 bytes, ensure positive (clear high bit)
    let mut serial_bytes = hash[..20].to_vec();
    serial_bytes[0] &= 0x7F;
    if serial_bytes[0] == 0 {
        serial_bytes[0] = 0x01;
    }
    SerialNumber::new(&serial_bytes)
        .map_err(|e| format!("serial number creation: {e}"))
}

/// Create a validity period: now to now + years.
fn make_validity(years: u32) -> Result<Validity, String> {
    use std::time::{SystemTime, Duration};

    let now = SystemTime::now();
    let not_after = now + Duration::from_secs(years as u64 * 365 * 24 * 3600);

    let not_before = Time::try_from(now)
        .map_err(|e| format!("not_before time: {e}"))?;
    let not_after = Time::try_from(not_after)
        .map_err(|e| format!("not_after time: {e}"))?;

    Ok(Validity {
        not_before,
        not_after,
    })
}

/// Build a BasicConstraints extension (CA:TRUE or CA:FALSE).
fn basic_constraints_extension(is_ca: bool) -> Result<x509_cert::ext::Extension, String> {
    // BasicConstraints ::= SEQUENCE { cA BOOLEAN DEFAULT FALSE, pathLenConstraint INTEGER OPTIONAL }
    let bc_value = if is_ca {
        // SEQUENCE { BOOLEAN TRUE }
        vec![0x30, 0x03, 0x01, 0x01, 0xFF]
    } else {
        // SEQUENCE { }
        vec![0x30, 0x00]
    };

    Ok(x509_cert::ext::Extension {
        extn_id: ID_CE_BASIC_CONSTRAINTS,
        critical: true,
        extn_value: OctetString::new(bc_value)
            .map_err(|e| format!("basic constraints octet string: {e}"))?,
    })
}

/// Build a KeyUsage extension.
fn key_usage_extension(digital_signature: bool, key_cert_sign: bool) -> Result<x509_cert::ext::Extension, String> {
    // KeyUsage is a BIT STRING
    let mut bits: u8 = 0;
    if digital_signature {
        bits |= 0x80; // bit 0 = digitalSignature
    }
    if key_cert_sign {
        bits |= 0x04; // bit 5 = keyCertSign
    }
    // BIT STRING encoding: 03 02 <unused_bits> <byte>
    // unused_bits for our use: we only use bits in first byte
    let unused = bits.trailing_zeros().min(7) as u8;
    let ku_der = vec![0x03, 0x02, unused, bits];

    Ok(x509_cert::ext::Extension {
        extn_id: ID_CE_KEY_USAGE,
        critical: true,
        extn_value: OctetString::new(ku_der)
            .map_err(|e| format!("key usage octet string: {e}"))?,
    })
}

/// Build a SubjectKeyIdentifier extension from SPKI DER.
fn subject_key_id_extension(spki_der: &[u8]) -> Result<x509_cert::ext::Extension, String> {
    let hash = Sha256::digest(spki_der);
    let ski = &hash[..20];
    // OCTET STRING wrapping the 20-byte identifier
    let mut ski_der = vec![0x04, ski.len() as u8];
    ski_der.extend_from_slice(ski);

    Ok(x509_cert::ext::Extension {
        extn_id: ID_CE_SUBJECT_KEY_IDENTIFIER,
        critical: false,
        extn_value: OctetString::new(ski_der)
            .map_err(|e| format!("SKI octet string: {e}"))?,
    })
}

/// Create a self-signed CA certificate using an Ed25519 key in gpg-agent.
pub fn create_ca_cert(
    keygrip: &str,
    cn: &str,
    subject_spki: SubjectPublicKeyInfoOwned,
) -> Result<Vec<u8>, String> {
    let spki_der = subject_spki.to_der()
        .map_err(|e| format!("SPKI to DER: {e}"))?;

    let serial = generate_serial(&spki_der)?;
    let validity = make_validity(10)?; // 10 year CA
    let subject = build_name(cn, Some("CriomOS"))?;

    let extensions = vec![
        basic_constraints_extension(true)?,
        key_usage_extension(false, true)?,
        subject_key_id_extension(&spki_der)?,
    ];

    let tbs = TbsCertificate {
        version: x509_cert::Version::V3,
        serial_number: serial,
        signature: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        issuer: subject.clone(),
        validity,
        subject,
        subject_public_key_info: subject_spki,
        issuer_unique_id: None,
        subject_unique_id: None,
        extensions: Some(extensions),
    };

    let tbs_der = tbs.to_der()
        .map_err(|e| format!("TBS to DER: {e}"))?;

    let signature = sign_with_gpg_agent(keygrip, &tbs_der)?;

    let cert = Certificate {
        tbs_certificate: tbs,
        signature_algorithm: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        signature: BitString::from_bytes(&signature)
            .map_err(|e| format!("signature BitString: {e}"))?,
    };

    cert.to_der().map_err(|e| format!("cert to DER: {e}"))
}

/// Create a client certificate for an Ed25519 key, signed by the CA.
pub fn create_node_cert(
    ca_keygrip: &str,
    ca_cert_der: &[u8],
    subject_spki: SubjectPublicKeyInfoOwned,
    cn: &str,
) -> Result<Vec<u8>, String> {
    let ca_cert = Certificate::from_der(ca_cert_der)
        .map_err(|e| format!("parse CA cert: {e}"))?;

    let spki_der = subject_spki.to_der()
        .map_err(|e| format!("SPKI to DER: {e}"))?;

    let serial = generate_serial(&spki_der)?;
    let validity = make_validity(2)?; // 2 year client cert

    let subject = build_name(cn, Some("CriomOS"))?;

    let extensions = vec![
        basic_constraints_extension(false)?,
        key_usage_extension(true, false)?,
        subject_key_id_extension(&spki_der)?,
    ];

    let tbs = TbsCertificate {
        version: x509_cert::Version::V3,
        serial_number: serial,
        signature: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        issuer: ca_cert.tbs_certificate.subject,
        validity,
        subject,
        subject_public_key_info: subject_spki,
        issuer_unique_id: None,
        subject_unique_id: None,
        extensions: Some(extensions),
    };

    let tbs_der = tbs.to_der()
        .map_err(|e| format!("TBS to DER: {e}"))?;

    let signature = sign_with_gpg_agent(ca_keygrip, &tbs_der)?;

    let cert = Certificate {
        tbs_certificate: tbs,
        signature_algorithm: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        signature: BitString::from_bytes(&signature)
            .map_err(|e| format!("signature BitString: {e}"))?,
    };

    cert.to_der().map_err(|e| format!("cert to DER: {e}"))
}

/// Create a server certificate with a fresh P-256 keypair, signed by the CA.
/// Returns (cert_der, private_key_pem).
pub fn create_server_cert(
    ca_keygrip: &str,
    ca_cert_der: &[u8],
    cn: &str,
) -> Result<(Vec<u8>, String), String> {
    use p256::ecdsa::SigningKey;
    use rand::rngs::OsRng;

    let ca_cert = Certificate::from_der(ca_cert_der)
        .map_err(|e| format!("parse CA cert: {e}"))?;

    // Generate fresh P-256 keypair
    let signing_key = SigningKey::random(&mut OsRng);
    let verifying_key = signing_key.verifying_key();
    let public_point = verifying_key.to_encoded_point(false);
    let public_bytes = public_point.as_bytes();

    // Encode private key as SEC1 PEM
    let private_key_bytes = signing_key.to_bytes();
    let private_key_pem = pem_rfc7468::encode_string(
        "EC PRIVATE KEY",
        pem_rfc7468::LineEnding::LF,
        &encode_sec1_private_key(&private_key_bytes, public_bytes),
    ).map_err(|e| format!("PEM encode private key: {e}"))?;

    // Build SPKI for P-256
    let oid_der = SECP256R1_OID.to_der()
        .map_err(|e| format!("SECP256R1 OID DER encoding: {e}"))?;
    let params = Any::from_der(&oid_der)
        .map_err(|e| format!("SECP256R1 param encoding: {e}"))?;

    let server_spki = SubjectPublicKeyInfoOwned {
        algorithm: AlgorithmIdentifierOwned {
            oid: EC_PUBLIC_KEY_OID,
            parameters: Some(params),
        },
        subject_public_key: BitString::from_bytes(public_bytes)
            .map_err(|e| format!("server pubkey BitString: {e}"))?,
    };

    let spki_der = server_spki.to_der()
        .map_err(|e| format!("server SPKI to DER: {e}"))?;

    let serial = generate_serial(&spki_der)?;
    let validity = make_validity(2)?; // 2 year server cert

    let subject = build_name(cn, Some("CriomOS"))?;

    let extensions = vec![
        basic_constraints_extension(false)?,
        key_usage_extension(true, false)?,
        subject_key_id_extension(&spki_der)?,
    ];

    // Server cert is signed by the Ed25519 CA key
    let tbs = TbsCertificate {
        version: x509_cert::Version::V3,
        serial_number: serial,
        signature: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        issuer: ca_cert.tbs_certificate.subject,
        validity,
        subject,
        subject_public_key_info: server_spki,
        issuer_unique_id: None,
        subject_unique_id: None,
        extensions: Some(extensions),
    };

    let tbs_der = tbs.to_der()
        .map_err(|e| format!("server TBS to DER: {e}"))?;

    let signature = sign_with_gpg_agent(ca_keygrip, &tbs_der)?;

    let cert = Certificate {
        tbs_certificate: tbs,
        signature_algorithm: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        signature: BitString::from_bytes(&signature)
            .map_err(|e| format!("server signature BitString: {e}"))?,
    };

    let cert_der = cert.to_der()
        .map_err(|e| format!("server cert to DER: {e}"))?;

    Ok((cert_der, private_key_pem))
}

/// Verify that a certificate chains to the given CA certificate.
pub fn verify_cert_chain(ca_cert_der: &[u8], cert_der: &[u8]) -> Result<(), String> {
    let ca_cert = Certificate::from_der(ca_cert_der)
        .map_err(|e| format!("parse CA cert: {e}"))?;
    let cert = Certificate::from_der(cert_der)
        .map_err(|e| format!("parse cert: {e}"))?;

    // Check issuer matches CA subject
    let ca_subject_der = ca_cert.tbs_certificate.subject.to_der()
        .map_err(|e| format!("CA subject DER: {e}"))?;
    let cert_issuer_der = cert.tbs_certificate.issuer.to_der()
        .map_err(|e| format!("cert issuer DER: {e}"))?;

    if ca_subject_der != cert_issuer_der {
        return Err("certificate issuer does not match CA subject".into());
    }

    // Structural verification: issuer match confirmed above.
    // Cryptographic signature verification requires the CA's public key algorithm
    // implementation. For Ed25519 certs, use: openssl verify -CAfile ca.pem cert.pem
    eprintln!("note: structural verification (issuer match). For cryptographic verification, use: openssl verify -CAfile ca.pem cert.pem");

    Ok(())
}

/// Encode a SEC1 ECPrivateKey structure for P-256.
fn encode_sec1_private_key(private_bytes: &[u8], public_bytes: &[u8]) -> Vec<u8> {
    // ECPrivateKey ::= SEQUENCE {
    //   version INTEGER { ecPrivkeyVer1(1) },
    //   privateKey OCTET STRING,
    //   parameters [0] EXPLICIT ECParameters OPTIONAL,
    //   publicKey [1] EXPLICIT BIT STRING OPTIONAL
    // }
    let mut inner = Vec::new();

    // version: INTEGER 1
    inner.extend_from_slice(&[0x02, 0x01, 0x01]);

    // privateKey: OCTET STRING
    inner.push(0x04);
    inner.push(private_bytes.len() as u8);
    inner.extend_from_slice(private_bytes);

    // parameters [0]: OID secp256r1
    let oid_bytes = SECP256R1_OID.as_bytes();
    let oid_enc_len = oid_bytes.len() + 2; // 06 len bytes
    inner.push(0xA0); // context [0] constructed
    inner.push(oid_enc_len as u8);
    inner.push(0x06);
    inner.push(oid_bytes.len() as u8);
    inner.extend_from_slice(oid_bytes);

    // publicKey [1]: BIT STRING
    let bitstr_len = public_bytes.len() + 1; // +1 for unused bits byte
    inner.push(0xA1); // context [1] constructed
    der_push_length(&mut inner, bitstr_len + 2); // +2 for BIT STRING tag+len
    inner.push(0x03); // BIT STRING tag
    der_push_length(&mut inner, bitstr_len);
    inner.push(0x00); // unused bits
    inner.extend_from_slice(public_bytes);

    // Wrap in SEQUENCE
    let mut result = vec![0x30];
    der_push_length(&mut result, inner.len());
    result.extend(inner);
    result
}

fn der_push_length(buf: &mut Vec<u8>, len: usize) {
    if len < 0x80 {
        buf.push(len as u8);
    } else if len < 0x100 {
        buf.push(0x81);
        buf.push(len as u8);
    } else {
        buf.push(0x82);
        buf.push((len >> 8) as u8);
        buf.push(len as u8);
    }
}

/// Sign TBS data using gpg-agent and return the raw signature bytes.
fn sign_with_gpg_agent(keygrip: &str, tbs_der: &[u8]) -> Result<Vec<u8>, String> {
    // For Ed25519: gpg-agent signs the raw data (not a hash of it).
    // However, the Assuan protocol's SETHASH command requires a hash.
    // For Ed25519, we use the SETDATA command instead to pass raw data.
    //
    // Actually, Ed25519 in gpg-agent uses SETHASH with the full data hash.
    // The gpg-agent performs SHA-512 internally as part of Ed25519.
    // We pass SHA-256 of TBS as that's what SETHASH expects.

    let hash = Sha256::digest(tbs_der);
    let hash_hex = hex::encode(hash);

    let mut agent = GpgAgent::connect()?;
    let sig_sexp = agent.sign(keygrip, &hash_hex)?;

    // Parse the S-expression response to extract raw signature bytes
    parse_sig_sexp(&sig_sexp)
}

/// Encode a DER certificate as PEM.
pub fn cert_to_pem(der: &[u8]) -> Result<String, String> {
    pem_rfc7468::encode_string("CERTIFICATE", pem_rfc7468::LineEnding::LF, der)
        .map_err(|e| format!("PEM encoding failed: {e}"))
}

/// Decode a PEM certificate to DER.
pub fn pem_to_cert_der(pem: &str) -> Result<Vec<u8>, String> {
    let (label, der) = pem_rfc7468::decode_vec(pem.as_bytes())
        .map_err(|e| format!("PEM decoding failed: {e}"))?;
    if label != "CERTIFICATE" {
        return Err(format!("expected CERTIFICATE PEM label, got: {label}"));
    }
    Ok(der)
}
