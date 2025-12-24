#[cfg(windows)]
use anyhow::{Context, Result};
#[cfg(windows)]
use std::path::PathBuf;
#[cfg(windows)]
use windows::{
    core::{Interface, PCWSTR, PROPVARIANT},
    Win32::{
        System::Com::{
            CoCreateInstance, CoInitializeEx, CoUninitialize, IPersistFile, CLSCTX_INPROC_SERVER,
            COINIT_APARTMENTTHREADED,
        },
        UI::Shell::{IShellLinkW, ShellLink},
    },
};

pub const AUMID: &str = "Claude.ClaudeNotifier";
const SHORTCUT_NAME: &str = "Claude Notifier.lnk";

#[cfg(windows)]
pub fn get_start_menu_path() -> Result<PathBuf> {
    let base = directories::BaseDirs::new().context("Failed to get base directories")?;
    let start_menu = base
        .data_local_dir()
        .join("Microsoft")
        .join("Windows")
        .join("Start Menu")
        .join("Programs");
    Ok(start_menu)
}

#[cfg(windows)]
pub fn get_shortcut_path() -> Result<PathBuf> {
    Ok(get_start_menu_path()?.join(SHORTCUT_NAME))
}

#[cfg(windows)]
pub fn is_registered() -> bool {
    get_shortcut_path().map(|p| p.exists()).unwrap_or(false)
}

#[cfg(windows)]
pub fn register() -> Result<()> {
    let exe_path = std::env::current_exe().context("Failed to get executable path")?;
    let shortcut_path = get_shortcut_path()?;

    if let Some(parent) = shortcut_path.parent() {
        std::fs::create_dir_all(parent).context("Failed to create Start Menu directory")?;
    }

    unsafe {
        CoInitializeEx(None, COINIT_APARTMENTTHREADED)
            .ok()
            .context("Failed to initialize COM")?;

        let result = create_shortcut_with_aumid(&exe_path, &shortcut_path);

        CoUninitialize();
        result
    }
}

#[cfg(windows)]
unsafe fn create_shortcut_with_aumid(
    exe_path: &std::path::Path,
    shortcut_path: &std::path::Path,
) -> Result<()> {
    use windows::core::GUID;
    use windows::Win32::UI::Shell::PropertiesSystem::IPropertyStore;
    use windows::Win32::UI::Shell::PropertiesSystem::PROPERTYKEY;

    // PKEY_AppUserModel_ID: {9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}, 5
    const PKEY_APPUSERMODEL_ID: PROPERTYKEY = PROPERTYKEY {
        fmtid: GUID::from_u128(0x9F4C2855_9F79_4B39_A8D0_E1D42DE1D5F3),
        pid: 5,
    };

    let shell_link: IShellLinkW = CoCreateInstance(&ShellLink, None, CLSCTX_INPROC_SERVER)
        .context("Failed to create ShellLink")?;

    let exe_str: Vec<u16> = exe_path
        .to_string_lossy()
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();

    shell_link
        .SetPath(PCWSTR(exe_str.as_ptr()))
        .context("Failed to set shortcut path")?;

    if let Some(parent) = exe_path.parent() {
        let dir_str: Vec<u16> = parent
            .to_string_lossy()
            .encode_utf16()
            .chain(std::iter::once(0))
            .collect();
        shell_link
            .SetWorkingDirectory(PCWSTR(dir_str.as_ptr()))
            .context("Failed to set working directory")?;
    }

    let desc: Vec<u16> = "Claude Code Notification Tool"
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();
    shell_link
        .SetDescription(PCWSTR(desc.as_ptr()))
        .context("Failed to set description")?;

    // 设置 AUMID
    let prop_store: IPropertyStore = shell_link.cast().context("Failed to get IPropertyStore")?;

    let pv = PROPVARIANT::from(AUMID);

    prop_store
        .SetValue(&PKEY_APPUSERMODEL_ID, &pv)
        .context("Failed to set AUMID property")?;

    prop_store
        .Commit()
        .context("Failed to commit property store")?;

    // 保存快捷方式
    let persist_file: IPersistFile = shell_link.cast().context("Failed to get IPersistFile")?;

    let shortcut_str: Vec<u16> = shortcut_path
        .to_string_lossy()
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();

    persist_file
        .Save(PCWSTR(shortcut_str.as_ptr()), true)
        .context("Failed to save shortcut")?;

    Ok(())
}

#[cfg(windows)]
pub fn unregister() -> Result<()> {
    let shortcut_path = get_shortcut_path()?;
    if shortcut_path.exists() {
        std::fs::remove_file(&shortcut_path).context("Failed to remove shortcut")?;
    }
    Ok(())
}

#[cfg(not(windows))]
pub fn is_registered() -> bool {
    false
}

#[cfg(not(windows))]
pub fn register() -> anyhow::Result<()> {
    anyhow::bail!("Registration is only supported on Windows")
}

#[cfg(not(windows))]
pub fn unregister() -> anyhow::Result<()> {
    anyhow::bail!("Unregistration is only supported on Windows")
}
