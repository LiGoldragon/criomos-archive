use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::process::Command;

fn clavifaber() -> Command {
    let bin = env!("CARGO_BIN_EXE_clavifaber");
    Command::new(bin)
}

fn fresh_dir(name: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("clavifaber-test-{name}-{}", std::process::id()));
    if dir.exists() {
        fs::remove_dir_all(&dir).unwrap();
    }
    dir
}

#[test]
fn generate_new_complex() {
    let dir = fresh_dir("generate");
    let out = clavifaber()
        .args(["complex-init", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(out.status.success(), "stderr: {}", String::from_utf8_lossy(&out.stderr));

    let key = dir.join("key.pem");
    let pub_ = dir.join("ssh.pub");
    assert!(key.exists(), "key.pem missing");
    assert!(pub_.exists(), "ssh.pub missing");

    // Verify permissions
    let key_mode = fs::metadata(&key).unwrap().permissions().mode() & 0o777;
    assert_eq!(key_mode, 0o600, "key.pem should be 0600, got {key_mode:o}");

    let pub_mode = fs::metadata(&pub_).unwrap().permissions().mode() & 0o777;
    assert_eq!(pub_mode, 0o644, "ssh.pub should be 0644, got {pub_mode:o}");

    // Verify key.pem is valid PEM
    let pem = fs::read_to_string(&key).unwrap();
    assert!(pem.contains("BEGIN PRIVATE KEY"), "key.pem not valid PEM");
    assert!(pem.contains("END PRIVATE KEY"), "key.pem not valid PEM");

    // Verify ssh.pub is valid OpenSSH format
    let ssh = fs::read_to_string(&pub_).unwrap();
    assert!(ssh.starts_with("ssh-ed25519 "), "ssh.pub wrong format: {ssh}");
    assert!(ssh.ends_with(" complex"), "ssh.pub missing 'complex' comment");

    // stdout should have the pubkey
    let stdout = String::from_utf8_lossy(&out.stdout);
    assert!(stdout.starts_with("ssh-ed25519 "), "stdout should be pubkey");

    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn idempotent_reinit() {
    let dir = fresh_dir("idempotent");
    // Generate
    let out1 = clavifaber()
        .args(["complex-init", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(out1.status.success());
    let key1 = fs::read_to_string(dir.join("key.pem")).unwrap();
    let pub1 = String::from_utf8_lossy(&out1.stdout).to_string();

    // Re-run
    let out2 = clavifaber()
        .args(["complex-init", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(out2.status.success());
    let key2 = fs::read_to_string(dir.join("key.pem")).unwrap();
    let pub2 = String::from_utf8_lossy(&out2.stdout).to_string();

    // Key should be identical (not regenerated)
    assert_eq!(key1, key2, "key.pem changed on re-init");
    assert_eq!(pub1, pub2, "pubkey changed on re-init");

    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn corrupt_key_recovery() {
    let dir = fresh_dir("corrupt");
    // Generate valid key
    let out1 = clavifaber()
        .args(["complex-init", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(out1.status.success());
    let original_pub = String::from_utf8_lossy(&out1.stdout).trim().to_string();

    // Corrupt the key
    fs::write(dir.join("key.pem"), b"CORRUPT DATA").unwrap();

    // Re-init should detect corruption and regenerate
    let out2 = clavifaber()
        .args(["complex-init", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(out2.status.success(), "stderr: {}", String::from_utf8_lossy(&out2.stderr));

    // Stderr should mention corruption
    let stderr = String::from_utf8_lossy(&out2.stderr);
    assert!(stderr.contains("corrupt"), "should warn about corruption: {stderr}");

    // New key should be different
    let new_pub = String::from_utf8_lossy(&out2.stdout).trim().to_string();
    assert_ne!(original_pub, new_pub, "should have generated a new key");

    // Broken file should be preserved
    let broken_files: Vec<_> = fs::read_dir(&dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().contains("broken"))
        .collect();
    assert!(!broken_files.is_empty(), "broken key should be preserved");

    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn derive_pubkey_matches() {
    let dir = fresh_dir("derive");
    // Generate
    let out1 = clavifaber()
        .args(["complex-init", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(out1.status.success());
    let init_pub = String::from_utf8_lossy(&out1.stdout).trim().to_string();

    // Tamper with ssh.pub (simulate divergence)
    fs::write(dir.join("ssh.pub"), "ssh-ed25519 AAAA_WRONG wrong").unwrap();

    // Derive should fix it
    let out2 = clavifaber()
        .args(["derive-pubkey", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(out2.status.success(), "stderr: {}", String::from_utf8_lossy(&out2.stderr));
    let derived_pub = String::from_utf8_lossy(&out2.stdout).trim().to_string();

    assert_eq!(init_pub, derived_pub, "derived pubkey should match original");

    // ssh.pub file should be corrected
    let file_pub = fs::read_to_string(dir.join("ssh.pub")).unwrap();
    assert_eq!(file_pub, derived_pub, "ssh.pub file should be corrected");

    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn atomic_write_permissions() {
    let dir = fresh_dir("atomic");
    // Generate
    clavifaber()
        .args(["complex-init", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();

    // No .tmp files should remain
    let tmp_files: Vec<_> = fs::read_dir(&dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().ends_with(".tmp"))
        .collect();
    assert!(tmp_files.is_empty(), "no .tmp files should remain: {tmp_files:?}");

    // Directory should be 0700
    let dir_mode = fs::metadata(&dir).unwrap().permissions().mode() & 0o777;
    assert_eq!(dir_mode, 0o700, "dir should be 0700, got {dir_mode:o}");

    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn derive_pubkey_fails_without_key() {
    let dir = fresh_dir("nokey");
    fs::create_dir_all(&dir).unwrap();

    let out = clavifaber()
        .args(["derive-pubkey", "--dir", dir.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(!out.status.success(), "should fail without key");

    fs::remove_dir_all(&dir).unwrap();
}
