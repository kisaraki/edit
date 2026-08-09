// Copyright (c) Microsoft Corporation.
// Modifications Copyright (c) 2026 KOSMOS, Tzhushh.K.
// Licensed under the MIT License.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use edit::buffer::TextBuffer;
use edit::cell::{Ref, SemiRefCell};
use edit::lsh::{LANGUAGES, Language};
use edit::oklab::StraightRgba;
use edit::{json, path as edit_path};
use stdext::arena::{read_to_string, scratch_arena};
use stdext::arena_format;

use crate::apperr;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Theme {
    #[default]
    Default,
    Mspwb,
    Cia,
    Mm14,
    XtAtStyle,
}

#[derive(Clone, Copy)]
pub struct ThemeColors {
    pub background: StraightRgba,
    pub foreground: StraightRgba,
    pub selection_background: StraightRgba,
    pub selection_foreground: StraightRgba,
}

impl Theme {
    // EN: These are the five user-selectable msedit-tzk screen themes.
    // 中文：以下為 msedit-tzk 提供使用者選擇的五種畫面主題。
    pub const ALL: [Theme; 5] =
        [Theme::Default, Theme::Mspwb, Theme::Cia, Theme::Mm14, Theme::XtAtStyle];

    pub const fn display_name(self) -> &'static str {
        match self {
            Theme::Default => "DEFAULT",
            Theme::Mspwb => "MSPWB",
            Theme::Cia => "CIA",
            Theme::Mm14 => "MM14",
            Theme::XtAtStyle => "XT/AT Style",
        }
    }

    pub const fn setting_name(self) -> &'static str {
        match self {
            Theme::Default => "DEFAULT",
            Theme::Mspwb => "MSPWB",
            Theme::Cia => "CIA",
            Theme::Mm14 => "MM14",
            Theme::XtAtStyle => "XT/AT Style",
        }
    }

    fn from_setting_name(value: &str) -> Option<Self> {
        // EN: Accept historical theme labels while always writing the current label.
        // 中文：讀取時相容舊主題名稱，儲存時一律寫入目前名稱。
        if value.eq_ignore_ascii_case("DEFAULT") {
            Some(Theme::Default)
        } else if value.eq_ignore_ascii_case("MSPWB") || value.eq_ignore_ascii_case("Theme MSPWB") {
            Some(Theme::Mspwb)
        } else if value.eq_ignore_ascii_case("CIA") || value.eq_ignore_ascii_case("Theme CIA") {
            Some(Theme::Cia)
        } else if value.eq_ignore_ascii_case("MM14") || value.eq_ignore_ascii_case("Theme MM14") {
            Some(Theme::Mm14)
        } else if value.eq_ignore_ascii_case("XT/AT Style")
            || value.eq_ignore_ascii_case("IBM XT/AT")
            || value.eq_ignore_ascii_case("Theme IBM XT/AT")
        {
            Some(Theme::XtAtStyle)
        } else {
            None
        }
    }

    pub const fn colors(self) -> Option<ThemeColors> {
        let rgba = StraightRgba::from_rgba;
        match self {
            Theme::Default => None,
            Theme::Mspwb => Some(ThemeColors {
                background: rgba(0x0000ffff),
                foreground: rgba(0xffffffff),
                selection_background: rgba(0x000000ff),
                selection_foreground: rgba(0x00ff00ff),
            }),
            Theme::Cia => Some(ThemeColors {
                background: rgba(0x0a2240ff),
                foreground: rgba(0xffffffff),
                selection_background: rgba(0x000000ff),
                selection_foreground: rgba(0x00ff00ff),
            }),
            Theme::Mm14 => Some(ThemeColors {
                background: rgba(0x000000ff),
                foreground: rgba(0xe6cea7ff),
                selection_background: rgba(0xe6cea7ff),
                selection_foreground: rgba(0x000000ff),
            }),
            Theme::XtAtStyle => Some(ThemeColors {
                background: rgba(0x000000ff),
                foreground: rgba(0x00ff00ff),
                selection_background: rgba(0x00ff00ff),
                selection_foreground: rgba(0x000000ff),
            }),
        }
    }
}

pub struct Settings {
    pub path: PathBuf,
    pub theme: Theme,
    pub file_associations: Vec<(String, &'static Language)>,
    pub recent_files: Vec<PathBuf>,
}

struct SettingsCell(SemiRefCell<Settings>);
unsafe impl Sync for SettingsCell {}
static SETTINGS: SettingsCell = SettingsCell(SemiRefCell::new(Settings::new()));

impl Settings {
    /// Fills the given settings.json text buffer with some initial contents for convenience.
    pub fn bootstrap(tb: &mut TextBuffer) {
        tb.set_crlf(false);
        let contents = Self::borrow().to_json();
        tb.write_raw(contents.as_bytes());
        tb.cursor_move_to_logical(Default::default());
        tb.mark_as_clean();
    }

    const fn new() -> Self {
        Settings {
            path: PathBuf::new(),
            theme: Theme::Default,
            file_associations: Vec::new(),
            recent_files: Vec::new(),
        }
    }

    pub fn borrow() -> Ref<'static, Settings> {
        SETTINGS.0.borrow()
    }

    pub fn reload() -> apperr::Result<()> {
        let s = &mut *SETTINGS.0.borrow_mut();

        // Reset all members if we had been loaded previously.
        if !s.path.as_os_str().is_empty() {
            *s = Settings::new();
        }

        s.load()
    }

    fn load(&mut self) -> apperr::Result<()> {
        self.path = match settings_json_path() {
            Some(p) => p,
            None => return Ok(()),
        };

        let scratch = scratch_arena(None);
        let str = match read_to_string(&scratch, &self.path) {
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(()),
            Err(err) => return Err(err.into()),
            Ok(str) => str,
        };
        let Ok(json) = json::parse(&scratch, &str) else {
            return Err(apperr::Error::SettingsInvalid("Invalid JSON"));
        };
        let Some(root) = json.as_object() else {
            return Err(apperr::Error::SettingsInvalid("Non-object root"));
        };

        if let Some(value) = root.get("theme") {
            let Some(value) = value.as_str() else {
                return Err(apperr::Error::SettingsInvalid("theme"));
            };
            let Some(theme) = Theme::from_setting_name(value) else {
                return Err(apperr::Error::SettingsInvalid("theme"));
            };
            self.theme = theme;
        }

        if let Some(f) = root.get_object("files.associations") {
            for &(mut key, ref value) in f.iter() {
                if !key.contains('/') {
                    key = arena_format!(&*scratch, "**/{key}").leak();
                }

                let Some(id) = value.as_str() else {
                    return Err(apperr::Error::SettingsInvalid("files.associations"));
                };
                let Some(language) = LANGUAGES.iter().find(|lang| lang.id == id) else {
                    return Err(apperr::Error::SettingsInvalid("language ID"));
                };

                self.file_associations.push((key.to_string(), language));
            }
        }

        // EN: Persist at most five unique absolute paths, newest first.
        // 中文：最近開啟檔案最多保存五筆不重複的絕對路徑，最新項目在前。
        if let Some(value) = root.get("files.recent") {
            let Some(values) = value.as_array() else {
                return Err(apperr::Error::SettingsInvalid("files.recent"));
            };
            for value in values.iter().take(5) {
                let Some(value) = value.as_str() else {
                    return Err(apperr::Error::SettingsInvalid("files.recent"));
                };
                let path = PathBuf::from(value);
                if !path.is_absolute() {
                    return Err(apperr::Error::SettingsInvalid("files.recent"));
                }
                let path = edit_path::normalize(&path);
                if !self.recent_files.contains(&path) {
                    self.recent_files.push(path);
                }
            }
        }

        Ok(())
    }

    pub fn set_theme(theme: Theme) -> apperr::Result<()> {
        let settings = &mut *SETTINGS.0.borrow_mut();
        settings.theme = theme;
        settings.save()
    }

    pub fn record_recent_file(path: &Path) -> apperr::Result<()> {
        // EN: Normalize every successful open before moving it to the front of the MRU list.
        // 中文：成功開啟檔案後先正規化路徑，再移至最近檔案清單最前方。
        let absolute = if path.is_absolute() {
            path.to_path_buf()
        } else {
            std::env::current_dir()?.join(path)
        };
        let absolute = edit_path::normalize(&absolute);
        let settings = &mut *SETTINGS.0.borrow_mut();
        settings.remember_recent_file(absolute);
        settings.save()
    }

    fn remember_recent_file(&mut self, path: PathBuf) {
        self.recent_files.retain(|recent| recent != &path);
        self.recent_files.insert(0, path);
        self.recent_files.truncate(5);
    }

    fn save(&self) -> apperr::Result<()> {
        if self.path.as_os_str().is_empty() {
            return Ok(());
        }
        if let Some(parent) = self.path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        std::fs::write(&self.path, self.to_json())?;
        Ok(())
    }

    fn to_json(&self) -> String {
        // EN: Serialize settings ourselves so generated files always use LF on every platform.
        // 中文：自行序列化設定，確保所有平台產生的檔案皆固定使用 LF。
        let mut contents = String::new();
        contents.push_str("{\n  \"theme\": ");
        write_json_string(&mut contents, self.theme.setting_name());
        contents.push_str(",\n  \"files.associations\": {");

        for (index, (pattern, language)) in self.file_associations.iter().enumerate() {
            contents.push_str(if index == 0 { "\n    " } else { ",\n    " });
            write_json_string(&mut contents, pattern);
            contents.push_str(": ");
            write_json_string(&mut contents, language.id);
        }

        if !self.file_associations.is_empty() {
            contents.push('\n');
            contents.push_str("  ");
        }
        contents.push_str("},\n  \"files.recent\": [");

        for (index, path) in self.recent_files.iter().enumerate() {
            contents.push_str(if index == 0 { "\n    " } else { ",\n    " });
            write_json_string(&mut contents, &path.to_string_lossy());
        }

        if !self.recent_files.is_empty() {
            contents.push('\n');
            contents.push_str("  ");
        }
        contents.push_str("]\n}\n");
        contents
    }
}

fn write_json_string(output: &mut String, value: &str) {
    output.push('"');
    for ch in value.chars() {
        match ch {
            '"' => output.push_str("\\\""),
            '\\' => output.push_str("\\\\"),
            '\u{08}' => output.push_str("\\b"),
            '\u{0c}' => output.push_str("\\f"),
            '\n' => output.push_str("\\n"),
            '\r' => output.push_str("\\r"),
            '\t' => output.push_str("\\t"),
            '\0'..='\u{1f}' => _ = write!(output, "\\u{:04x}", ch as u32),
            _ => output.push(ch),
        }
    }
    output.push('"');
}

fn settings_json_path() -> Option<PathBuf> {
    let mut config_dir = config_dir()?;
    config_dir.push("settings.json");
    Some(config_dir)
}

fn config_dir() -> Option<PathBuf> {
    fn var_path(key: &str) -> Option<PathBuf> {
        std::env::var_os(key).map(PathBuf::from)
    }

    fn push(mut path: PathBuf, suffix: &str) -> PathBuf {
        path.push(suffix);
        path
    }

    #[cfg(target_os = "windows")]
    {
        var_path("APPDATA").map(|p| push(p, "TZK\\Edit"))
    }
    #[cfg(any(target_os = "macos", target_os = "ios"))]
    {
        var_path("HOME").map(|p| push(p, "Library/Application Support/com.tzk.edit"))
    }
    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "ios")))]
    {
        var_path("XDG_CONFIG_HOME")
            .or_else(|| var_path("HOME").map(|p| push(p, ".config")))
            .map(|p| push(p, "msedit-tzk"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn theme_names_round_trip() {
        for theme in Theme::ALL {
            assert_eq!(Theme::from_setting_name(theme.setting_name()), Some(theme));
            assert!(!theme.display_name().starts_with("Theme "));
        }
        assert_eq!(Theme::from_setting_name("XT/AT Style"), Some(Theme::XtAtStyle));
        assert_eq!(Theme::from_setting_name("Theme IBM XT/AT"), Some(Theme::XtAtStyle));
        assert_eq!(Theme::from_setting_name("unknown"), None);
    }

    #[test]
    fn theme_colors_match_specification() {
        let mspwb = Theme::Mspwb.colors().unwrap();
        assert_eq!(mspwb.background.to_rgba(), 0x0000ffff);
        assert_eq!(mspwb.foreground.to_rgba(), 0xffffffff);
        assert_eq!(mspwb.selection_background.to_rgba(), 0x000000ff);
        assert_eq!(mspwb.selection_foreground.to_rgba(), 0x00ff00ff);

        let cia = Theme::Cia.colors().unwrap();
        assert_eq!(cia.background.to_rgba(), 0x0a2240ff);

        let mm14 = Theme::Mm14.colors().unwrap();
        assert_eq!(mm14.foreground.to_rgba(), 0xe6cea7ff);
        assert_eq!(mm14.selection_background.to_rgba(), 0xe6cea7ff);

        let xt_at = Theme::XtAtStyle.colors().unwrap();
        assert_eq!(xt_at.foreground.to_rgba(), 0x00ff00ff);
        assert_eq!(xt_at.selection_background.to_rgba(), 0x00ff00ff);
    }

    #[test]
    fn theme_setting_serializes_as_lf_json() {
        let mut settings = Settings::new();
        settings.theme = Theme::Cia;
        assert_eq!(
            settings.to_json(),
            "{\n  \"theme\": \"CIA\",\n  \"files.associations\": {},\n  \"files.recent\": []\n}\n"
        );
    }

    #[test]
    fn recent_files_keep_the_newest_unique_five_paths() {
        let mut settings = Settings::new();
        for name in ["one", "two", "three", "four", "five", "six", "four"] {
            settings.remember_recent_file(PathBuf::from(name));
        }
        assert_eq!(
            settings.recent_files,
            ["four", "six", "five", "three", "two"].map(PathBuf::from)
        );
    }
}
