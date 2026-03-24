use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::process::Command;

/// Client for gpg-agent's Assuan protocol.
/// Performs signing operations via SIGKEY/SETHASH/PKSIGN commands.
pub struct GpgAgent {
    stream: BufReader<UnixStream>,
}

impl GpgAgent {
    pub fn connect() -> Result<Self, String> {
        let output = Command::new("gpgconf")
            .args(["--list-dirs", "agent-socket"])
            .output()
            .map_err(|e| format!("gpgconf failed: {e}"))?;

        let socket_path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if socket_path.is_empty() {
            return Err("gpgconf returned empty agent-socket path".into());
        }

        let raw = UnixStream::connect(&socket_path)
            .map_err(|e| format!("connect to {socket_path}: {e}"))?;
        let mut agent = Self {
            stream: BufReader::new(raw),
        };

        // Read the server greeting
        let greeting = agent.read_line()?;
        if !greeting.starts_with("OK") {
            return Err(format!("unexpected greeting: {greeting}"));
        }

        Ok(agent)
    }

    /// Sign a hash using the specified keygrip.
    /// Returns raw signature bytes (Ed25519: 64 bytes, ECDSA: DER-encoded).
    pub fn sign(&mut self, keygrip: &str, hash_hex: &str) -> Result<Vec<u8>, String> {
        // Select the signing key
        self.send_command(&format!("SIGKEY {keygrip}"))?;
        self.expect_ok()?;

        // Set the hash to sign
        self.send_command(&format!("SETHASH --hash=sha256 {hash_hex}"))?;
        self.expect_ok()?;

        // Request the signature
        self.send_command("PKSIGN")?;
        let sig_data = self.read_data_response()?;

        Ok(sig_data)
    }

    fn send_command(&mut self, cmd: &str) -> Result<(), String> {
        let stream = self.stream.get_mut();
        stream
            .write_all(format!("{cmd}\n").as_bytes())
            .map_err(|e| format!("write failed: {e}"))?;
        stream.flush().map_err(|e| format!("flush failed: {e}"))
    }

    /// Read a line as UTF-8 (for ASCII-only responses like OK, ERR, greeting).
    fn read_line(&mut self) -> Result<String, String> {
        let mut line = String::new();
        self.stream
            .read_line(&mut line)
            .map_err(|e| format!("read failed: {e}"))?;
        Ok(line.trim_end().to_string())
    }

    /// Read a raw line as bytes (for D-lines that may contain binary data).
    fn read_raw_line(&mut self) -> Result<Vec<u8>, String> {
        let mut buf = Vec::new();
        self.stream
            .read_until(b'\n', &mut buf)
            .map_err(|e| format!("read failed: {e}"))?;
        while buf.last() == Some(&b'\n') || buf.last() == Some(&b'\r') {
            buf.pop();
        }
        Ok(buf)
    }

    fn expect_ok(&mut self) -> Result<(), String> {
        let line = self.read_line()?;
        if line.starts_with("OK") {
            Ok(())
        } else if line.starts_with("ERR") {
            Err(format!("gpg-agent error: {line}"))
        } else {
            Err(format!("unexpected response: {line}"))
        }
    }

    /// Read a D-line data response followed by OK.
    /// Uses byte-level reading since D-lines may contain non-UTF-8 data.
    fn read_data_response(&mut self) -> Result<Vec<u8>, String> {
        let mut data = Vec::new();
        loop {
            let line = self.read_raw_line()?;
            if line.starts_with(b"D ") {
                data.extend(decode_assuan_bytes(&line[2..]));
            } else if line.starts_with(b"OK") {
                break;
            } else if line.starts_with(b"ERR") {
                let msg = String::from_utf8_lossy(&line);
                return Err(format!("gpg-agent error: {msg}"));
            } else if line.starts_with(b"INQUIRE") {
                self.send_command("END")?;
            }
        }
        Ok(data)
    }
}

/// Decode Assuan percent-encoded data from raw bytes.
fn decode_assuan_bytes(bytes: &[u8]) -> Vec<u8> {
    let mut result = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hi = bytes[i + 1];
            let lo = bytes[i + 2];
            if let (Some(h), Some(l)) = (hex_val(hi), hex_val(lo)) {
                result.push(h << 4 | l);
                i += 3;
                continue;
            }
        }
        result.push(bytes[i]);
        i += 1;
    }
    result
}

fn hex_val(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

/// Extract the raw signature value from gpg-agent's S-expression response.
/// gpg-agent returns: (7:sig-val(5:eddsa(1:r32:<bytes>)(1:s32:<bytes>)))
/// or for ECDSA: (7:sig-val(5:ecdsa(1:r<len>:<bytes>)(1:s<len>:<bytes>)))
/// We need to extract and concatenate r and s values.
pub fn parse_sig_sexp(data: &[u8]) -> Result<Vec<u8>, String> {
    // Find the r value
    let r_bytes = extract_sexp_value(data, b"r")
        .ok_or("could not find 'r' in signature S-expression")?;
    let s_bytes = extract_sexp_value(data, b"s")
        .ok_or("could not find 's' in signature S-expression")?;

    let mut sig = Vec::with_capacity(r_bytes.len() + s_bytes.len());
    sig.extend_from_slice(r_bytes);
    sig.extend_from_slice(s_bytes);
    Ok(sig)
}

fn extract_sexp_value<'a>(data: &'a [u8], tag: &[u8]) -> Option<&'a [u8]> {
    // Look for pattern: (1:<tag><len>:<value>)
    // The format is: (<tag_len>:<tag><value_len>:<value>)
    let needle_prefix = format!("(1:{}", String::from_utf8_lossy(tag));
    let needle = needle_prefix.as_bytes();

    let pos = data
        .windows(needle.len())
        .position(|w| w == needle)?;

    let after_tag = pos + needle.len();
    // Now parse the length: digits followed by ':'
    let mut i = after_tag;
    let mut len_str = String::new();
    while i < data.len() && data[i].is_ascii_digit() {
        len_str.push(data[i] as char);
        i += 1;
    }
    if i >= data.len() || data[i] != b':' {
        return None;
    }
    i += 1; // skip ':'

    let len: usize = len_str.parse().ok()?;
    if i + len > data.len() {
        return None;
    }
    Some(&data[i..i + len])
}
