use crate::error::Error;
use crate::gpg_agent::{parse_sig_sexp, GpgAgent};
use const_oid::db::rfc5280::{
    ID_CE_BASIC_CONSTRAINTS, ID_CE_KEY_USAGE, ID_CE_SUBJECT_KEY_IDENTIFIER,
};
use der::asn1::{BitString, ObjectIdentifier, OctetString, SetOfVec};
use der::{Any, Decode, Encode, Tag};
use sha2::{Digest, Sha256};
use spki::{AlgorithmIdentifierOwned, SubjectPublicKeyInfoOwned};
use x509_cert::attr::AttributeTypeAndValue;
use x509_cert::name::{Name, RdnSequence, RelativeDistinguishedName};
use x509_cert::serial_number::SerialNumber;
use x509_cert::time::{Time, Validity};
use x509_cert::{Certificate, TbsCertificate};

const ED25519_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.3.101.112");
const EC_PUBLIC_KEY_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.2.840.10045.2.1");
const SECP256R1_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.2.840.10045.3.1.7");
const CN_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("2.5.4.3");
const ORG_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("2.5.4.10");

fn build_name(cn: &str, org: Option<&str>) -> Result<Name, Error> {
    let mut rdns = Vec::new();

    if let Some(org_str) = org {
        let org_value = Any::new(Tag::Utf8String, org_str.as_bytes())
            .map_err(|e| Error::Certificate(format!("org encoding: {e}")))?;
        let org_atv = AttributeTypeAndValue {
            oid: ORG_OID,
            value: org_value,
        };
        let org_set = SetOfVec::try_from(vec![org_atv])
            .map_err(|e| Error::Certificate(format!("org RDN: {e}")))?;
        rdns.push(RelativeDistinguishedName::from(org_set));
    }

    let cn_value = Any::new(Tag::Utf8String, cn.as_bytes())
        .map_err(|e| Error::Certificate(format!("cn encoding: {e}")))?;
    let cn_atv = AttributeTypeAndValue {
        oid: CN_OID,
        value: cn_value,
    };
    let cn_set = SetOfVec::try_from(vec![cn_atv])
        .map_err(|e| Error::Certificate(format!("cn RDN: {e}")))?;
    rdns.push(RelativeDistinguishedName::from(cn_set));

    Ok(Name::from(RdnSequence::from(rdns)))
}

fn generate_serial(spki_der: &[u8]) -> Result<SerialNumber, Error> {
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
    let mut serial_bytes = hash[..20].to_vec();
    serial_bytes[0] &= 0x7F;
    if serial_bytes[0] == 0 {
        serial_bytes[0] = 0x01;
    }
    SerialNumber::new(&serial_bytes).map_err(|e| Error::Certificate(format!("serial: {e}")))
}

fn make_validity(years: u32) -> Result<Validity, Error> {
    use std::time::{Duration, SystemTime};

    let now = SystemTime::now();
    let not_after = now + Duration::from_secs(years as u64 * 365 * 24 * 3600);

    Ok(Validity {
        not_before: Time::try_from(now)
            .map_err(|e| Error::Certificate(format!("not_before: {e}")))?,
        not_after: Time::try_from(not_after)
            .map_err(|e| Error::Certificate(format!("not_after: {e}")))?,
    })
}

fn basic_constraints_extension(is_ca: bool) -> Result<x509_cert::ext::Extension, Error> {
    let bc_value = if is_ca {
        vec![0x30, 0x03, 0x01, 0x01, 0xFF]
    } else {
        vec![0x30, 0x00]
    };
    Ok(x509_cert::ext::Extension {
        extn_id: ID_CE_BASIC_CONSTRAINTS,
        critical: true,
        extn_value: OctetString::new(bc_value)
            .map_err(|e| Error::Certificate(format!("basic constraints: {e}")))?,
    })
}

fn key_usage_extension(
    digital_signature: bool,
    key_cert_sign: bool,
) -> Result<x509_cert::ext::Extension, Error> {
    let mut bits: u8 = 0;
    if digital_signature {
        bits |= 0x80;
    }
    if key_cert_sign {
        bits |= 0x04;
    }
    let unused = bits.trailing_zeros().min(7) as u8;
    let ku_der = vec![0x03, 0x02, unused, bits];
    Ok(x509_cert::ext::Extension {
        extn_id: ID_CE_KEY_USAGE,
        critical: true,
        extn_value: OctetString::new(ku_der)
            .map_err(|e| Error::Certificate(format!("key usage: {e}")))?,
    })
}

fn subject_key_id_extension(spki_der: &[u8]) -> Result<x509_cert::ext::Extension, Error> {
    let hash = Sha256::digest(spki_der);
    let ski = &hash[..20];
    let mut ski_der = vec![0x04, ski.len() as u8];
    ski_der.extend_from_slice(ski);
    Ok(x509_cert::ext::Extension {
        extn_id: ID_CE_SUBJECT_KEY_IDENTIFIER,
        critical: false,
        extn_value: OctetString::new(ski_der)
            .map_err(|e| Error::Certificate(format!("SKI: {e}")))?,
    })
}

fn sign_tbs(keygrip: &str, tbs_der: &[u8]) -> Result<Vec<u8>, Error> {
    let hash = Sha256::digest(tbs_der);
    let hash_hex = hex::encode(hash);
    let mut agent = GpgAgent::connect()?;
    let sig_sexp = agent.sign(keygrip, &hash_hex)?;
    parse_sig_sexp(&sig_sexp)
}

fn build_cert(tbs: TbsCertificate, keygrip: &str) -> Result<Vec<u8>, Error> {
    let tbs_der = tbs
        .to_der()
        .map_err(|e| Error::Certificate(format!("TBS encode: {e}")))?;
    let signature = sign_tbs(keygrip, &tbs_der)?;
    let cert = Certificate {
        tbs_certificate: tbs,
        signature_algorithm: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        signature: BitString::from_bytes(&signature)
            .map_err(|e| Error::Certificate(format!("signature BitString: {e}")))?,
    };
    cert.to_der()
        .map_err(|e| Error::Certificate(format!("cert encode: {e}")))
}

pub fn create_ca_cert(
    keygrip: &str,
    cn: &str,
    subject_spki: SubjectPublicKeyInfoOwned,
) -> Result<Vec<u8>, Error> {
    let spki_der = subject_spki
        .to_der()
        .map_err(|e| Error::Certificate(format!("SPKI encode: {e}")))?;
    let subject = build_name(cn, Some("CriomOS"))?;
    let tbs = TbsCertificate {
        version: x509_cert::Version::V3,
        serial_number: generate_serial(&spki_der)?,
        signature: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        issuer: subject.clone(),
        validity: make_validity(10)?,
        subject,
        subject_public_key_info: subject_spki,
        issuer_unique_id: None,
        subject_unique_id: None,
        extensions: Some(vec![
            basic_constraints_extension(true)?,
            key_usage_extension(false, true)?,
            subject_key_id_extension(&spki_der)?,
        ]),
    };
    build_cert(tbs, keygrip)
}

pub fn create_node_cert(
    ca_keygrip: &str,
    ca_cert_der: &[u8],
    subject_spki: SubjectPublicKeyInfoOwned,
    cn: &str,
) -> Result<Vec<u8>, Error> {
    let ca_cert = Certificate::from_der(ca_cert_der)
        .map_err(|e| Error::Certificate(format!("parse CA: {e}")))?;
    let spki_der = subject_spki
        .to_der()
        .map_err(|e| Error::Certificate(format!("SPKI encode: {e}")))?;
    let tbs = TbsCertificate {
        version: x509_cert::Version::V3,
        serial_number: generate_serial(&spki_der)?,
        signature: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        issuer: ca_cert.tbs_certificate.subject,
        validity: make_validity(2)?,
        subject: build_name(cn, Some("CriomOS"))?,
        subject_public_key_info: subject_spki,
        issuer_unique_id: None,
        subject_unique_id: None,
        extensions: Some(vec![
            basic_constraints_extension(false)?,
            key_usage_extension(true, false)?,
            subject_key_id_extension(&spki_der)?,
        ]),
    };
    build_cert(tbs, ca_keygrip)
}

pub fn create_server_cert(
    ca_keygrip: &str,
    ca_cert_der: &[u8],
    cn: &str,
) -> Result<(Vec<u8>, String), Error> {
    use p256::ecdsa::SigningKey;
    use p256::pkcs8::EncodePrivateKey;
    use rand::rngs::OsRng;

    let ca_cert = Certificate::from_der(ca_cert_der)
        .map_err(|e| Error::Certificate(format!("parse CA: {e}")))?;

    let signing_key = SigningKey::random(&mut OsRng);
    let verifying_key = signing_key.verifying_key();
    let public_point = verifying_key.to_encoded_point(false);
    let public_bytes = public_point.as_bytes();

    // Encode private key using pkcs8 crate, then re-encode as SEC1 PEM via p256
    let secret_key = p256::SecretKey::from(signing_key);
    let private_key_pem = secret_key
        .to_pkcs8_pem(pem_rfc7468::LineEnding::LF)
        .map_err(|e| Error::Certificate(format!("server key encode: {e}")))?
        .to_string();

    let oid_der = SECP256R1_OID
        .to_der()
        .map_err(|e| Error::Certificate(format!("OID encode: {e}")))?;
    let params = Any::from_der(&oid_der)
        .map_err(|e| Error::Certificate(format!("param encode: {e}")))?;

    let server_spki = SubjectPublicKeyInfoOwned {
        algorithm: AlgorithmIdentifierOwned {
            oid: EC_PUBLIC_KEY_OID,
            parameters: Some(params),
        },
        subject_public_key: BitString::from_bytes(public_bytes)
            .map_err(|e| Error::Certificate(format!("pubkey BitString: {e}")))?,
    };

    let spki_der = server_spki
        .to_der()
        .map_err(|e| Error::Certificate(format!("SPKI encode: {e}")))?;

    let tbs = TbsCertificate {
        version: x509_cert::Version::V3,
        serial_number: generate_serial(&spki_der)?,
        signature: AlgorithmIdentifierOwned {
            oid: ED25519_OID,
            parameters: None,
        },
        issuer: ca_cert.tbs_certificate.subject,
        validity: make_validity(2)?,
        subject: build_name(cn, Some("CriomOS"))?,
        subject_public_key_info: server_spki,
        issuer_unique_id: None,
        subject_unique_id: None,
        extensions: Some(vec![
            basic_constraints_extension(false)?,
            key_usage_extension(true, false)?,
            subject_key_id_extension(&spki_der)?,
        ]),
    };

    let cert_der = build_cert(tbs, ca_keygrip)?;
    Ok((cert_der, private_key_pem))
}

pub fn verify_cert_chain(ca_cert_der: &[u8], cert_der: &[u8]) -> Result<(), Error> {
    let ca_cert = Certificate::from_der(ca_cert_der)
        .map_err(|e| Error::Certificate(format!("parse CA: {e}")))?;
    let cert = Certificate::from_der(cert_der)
        .map_err(|e| Error::Certificate(format!("parse cert: {e}")))?;

    // Issuer must match CA subject
    let ca_subject_der = ca_cert
        .tbs_certificate
        .subject
        .to_der()
        .map_err(|e| Error::Certificate(format!("CA subject encode: {e}")))?;
    let cert_issuer_der = cert
        .tbs_certificate
        .issuer
        .to_der()
        .map_err(|e| Error::Certificate(format!("cert issuer encode: {e}")))?;

    if ca_subject_der != cert_issuer_der {
        return Err(Error::Certificate(
            "issuer does not match CA subject".into(),
        ));
    }

    // Cryptographic verification: Ed25519 signature over SHA-256(TBS)
    // This matches the signing path in sign_tbs which uses SETHASH --hash=sha256.
    let ca_pubkey_bits = &ca_cert
        .tbs_certificate
        .subject_public_key_info
        .subject_public_key;
    let ca_pubkey_raw = ca_pubkey_bits.raw_bytes();

    let vk_bytes: [u8; 32] = ca_pubkey_raw.try_into().map_err(|_| {
        Error::Certificate(format!(
            "CA public key is {} bytes, expected 32",
            ca_pubkey_raw.len()
        ))
    })?;
    let verifying_key = ed25519_dalek::VerifyingKey::from_bytes(&vk_bytes)
        .map_err(|e| Error::Certificate(format!("CA public key invalid: {e}")))?;

    let tbs_der = cert
        .tbs_certificate
        .to_der()
        .map_err(|e| Error::Certificate(format!("TBS encode: {e}")))?;

    // The signature was computed over SHA-256(TBS) via gpg-agent SETHASH,
    // so we must verify over the same hash.
    let tbs_hash = Sha256::digest(&tbs_der);

    let sig_raw = cert.signature.raw_bytes();
    let sig_bytes: [u8; 64] = sig_raw.try_into().map_err(|_| {
        Error::Certificate(format!(
            "signature is {} bytes, expected 64",
            sig_raw.len()
        ))
    })?;
    let signature = ed25519_dalek::Signature::from_bytes(&sig_bytes);

    verifying_key
        .verify_strict(&tbs_hash, &signature)
        .map_err(|e| Error::Certificate(format!("signature verification failed: {e}")))?;

    Ok(())
}

pub fn cert_to_pem(der: &[u8]) -> Result<String, Error> {
    pem_rfc7468::encode_string("CERTIFICATE", pem_rfc7468::LineEnding::LF, der)
        .map_err(|e| Error::Certificate(format!("PEM encode: {e}")))
}

pub fn pem_to_cert_der(pem: &str) -> Result<Vec<u8>, Error> {
    let (label, der) = pem_rfc7468::decode_vec(pem.as_bytes())
        .map_err(|e| Error::Certificate(format!("PEM decode: {e}")))?;
    if label != "CERTIFICATE" {
        return Err(Error::Certificate(format!(
            "expected CERTIFICATE label, got: {label}"
        )));
    }
    Ok(der)
}
