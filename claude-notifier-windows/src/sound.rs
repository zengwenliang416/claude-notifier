#[cfg(windows)]
use anyhow::{Context, Result};
#[cfg(windows)]
use std::path::Path;
#[cfg(windows)]
use windows::{
    core::HSTRING, Foundation::Uri, Media::Core::MediaSource, Media::Playback::MediaPlayer,
};

#[cfg(windows)]
pub fn play_sound_file(path: &str) -> Result<()> {
    let path = Path::new(path);

    if !path.exists() {
        anyhow::bail!("Sound file not found: {}", path.display());
    }

    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    if ext != "wav" {
        anyhow::bail!("Only .wav files are supported on Windows (got .{})", ext);
    }

    let abs_path = path.canonicalize().context("Failed to get absolute path")?;

    let uri_str = format!(
        "file:///{}",
        abs_path.display().to_string().replace('\\', "/")
    );
    let uri = Uri::CreateUri(&HSTRING::from(&uri_str)).context("Failed to create URI")?;

    let source = MediaSource::CreateFromUri(&uri).context("Failed to create media source")?;

    let player = MediaPlayer::new().context("Failed to create media player")?;

    player
        .SetSource(&source)
        .context("Failed to set media source")?;

    player.Play().context("Failed to play sound")?;

    // 等待播放开始
    std::thread::sleep(std::time::Duration::from_millis(100));

    // 等待播放完成（简单实现：假设音效 ≤ 5 秒）
    // 实际应用中可以监听 MediaEnded 事件
    std::thread::sleep(std::time::Duration::from_secs(3));

    Ok(())
}

#[cfg(windows)]
pub fn play_system_sound(name: &str) -> Result<()> {
    // Windows 系统声音事件
    let sound_event = match name.to_lowercase().as_str() {
        "default" | "notification.default" => "Notification.Default",
        "mail" | "notification.mail" => "Notification.Mail",
        "reminder" | "notification.reminder" => "Notification.Reminder",
        "im" | "notification.im" => "Notification.IM",
        "alarm" | "alarm.default" => "Alarm.Default",
        _ => name,
    };

    // 系统声音通过 Toast 的 audio 元素播放，这里只返回事件名
    // 实际播放由 toast.rs 中的 XML 模板处理
    eprintln!("[INFO] System sound: {}", sound_event);
    Ok(())
}

#[cfg(not(windows))]
pub fn play_sound_file(_path: &str) -> anyhow::Result<()> {
    anyhow::bail!("Sound playback is only supported on Windows")
}

#[cfg(not(windows))]
pub fn play_system_sound(_name: &str) -> anyhow::Result<()> {
    anyhow::bail!("Sound playback is only supported on Windows")
}
