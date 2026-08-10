// Copyright (c) Microsoft Corporation.
// Modifications Copyright (c) 2026 KOSMOS, Tzushih.K.
// Licensed under the MIT License.

//! Platform abstractions.

use std::io;
use std::path::PathBuf;

#[cfg(unix)]
mod unix;
#[cfg(windows)]
mod windows;

#[cfg(not(windows))]
pub use std::fs::canonicalize;

#[cfg(unix)]
pub use unix::*;
#[cfg(windows)]
pub use windows::*;

/// EN: Resolves the Desktop through one cross-platform abstraction instead of OS APIs in app code.
/// 中文：透過單一跨平台抽象解析桌面路徑，避免應用程式碼直接使用特定作業系統 API。
pub fn desktop_dir() -> io::Result<PathBuf> {
    dirs::desktop_dir().ok_or_else(|| {
        io::Error::new(io::ErrorKind::NotFound, "the Desktop directory is unavailable")
    })
}
