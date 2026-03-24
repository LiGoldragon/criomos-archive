use std::fmt;
use std::path::PathBuf;

pub enum Error {
    Io { path: PathBuf, source: std::io::Error },
    Gpg(String),
    Parse(String),
    Corrupt { path: PathBuf, detail: String },
    Certificate(String),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Io { path, source } => write!(f, "{}: {source}", path.display()),
            Error::Gpg(msg) => write!(f, "gpg: {msg}"),
            Error::Parse(msg) => write!(f, "parse: {msg}"),
            Error::Corrupt { path, detail } => {
                write!(f, "corrupt key at {}: {detail}", path.display())
            }
            Error::Certificate(msg) => write!(f, "certificate: {msg}"),
        }
    }
}

impl From<String> for Error {
    fn from(s: String) -> Self {
        Error::Parse(s)
    }
}

impl From<&str> for Error {
    fn from(s: &str) -> Self {
        Error::Parse(s.to_string())
    }
}
