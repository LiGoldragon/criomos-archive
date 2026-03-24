use crate::error::Error;
use std::fs;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

/// Write contents to path atomically: write to .tmp, sync, chmod, rename.
pub fn atomic_write(path: &Path, contents: &[u8], mode: u32) -> Result<(), Error> {
    let tmp = path.with_extension("tmp");
    let mut f = fs::File::create(&tmp).map_err(|e| Error::Io {
        path: tmp.clone(),
        source: e,
    })?;
    f.write_all(contents).map_err(|e| Error::Io {
        path: tmp.clone(),
        source: e,
    })?;
    f.sync_all().map_err(|e| Error::Io {
        path: tmp.clone(),
        source: e,
    })?;
    drop(f);
    fs::set_permissions(&tmp, fs::Permissions::from_mode(mode)).map_err(|e| Error::Io {
        path: tmp.clone(),
        source: e,
    })?;
    fs::rename(&tmp, path).map_err(|e| Error::Io {
        path: path.to_path_buf(),
        source: e,
    })?;
    Ok(())
}

/// Decode Assuan percent-encoded data from raw bytes.
pub fn decode_assuan_bytes(bytes: &[u8]) -> Vec<u8> {
    let mut result = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let (Some(h), Some(l)) = (hex_val(bytes[i + 1]), hex_val(bytes[i + 2])) {
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
