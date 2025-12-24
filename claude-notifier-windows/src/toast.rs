#[cfg(windows)]
use anyhow::{Context, Result};
#[cfg(windows)]
use windows::{
    core::HSTRING,
    Data::Xml::Dom::XmlDocument,
    UI::Notifications::{ToastNotification, ToastNotificationManager},
};

use crate::registration::AUMID;

#[cfg(windows)]
pub fn send_notification(title: &str, message: &str, silent: bool) -> Result<()> {
    let xml = create_toast_xml(title, message, silent)?;

    let toast = ToastNotification::CreateToastNotification(&xml)
        .context("Failed to create toast notification")?;

    let notifier = ToastNotificationManager::CreateToastNotifierWithId(&HSTRING::from(AUMID))
        .context("Failed to create toast notifier")?;

    notifier
        .Show(&toast)
        .context("Failed to show notification")?;

    // 等待通知显示
    std::thread::sleep(std::time::Duration::from_millis(100));

    Ok(())
}

#[cfg(windows)]
fn create_toast_xml(title: &str, message: &str, silent: bool) -> Result<XmlDocument> {
    let audio_xml = if silent {
        r#"<audio silent="true"/>"#
    } else {
        r#"<audio src="ms-winsoundevent:Notification.Default"/>"#
    };

    let xml_string = format!(
        r#"<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>{}</text>
            <text>{}</text>
        </binding>
    </visual>
    {}
</toast>"#,
        escape_xml(title),
        escape_xml(message),
        audio_xml
    );

    let xml = XmlDocument::new().context("Failed to create XmlDocument")?;
    xml.LoadXml(&HSTRING::from(&xml_string))
        .context("Failed to load toast XML")?;

    Ok(xml)
}

fn escape_xml(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

#[cfg(not(windows))]
pub fn send_notification(_title: &str, _message: &str, _silent: bool) -> anyhow::Result<()> {
    anyhow::bail!("Toast notifications are only supported on Windows")
}
