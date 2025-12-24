mod cli;
mod registration;
mod sound;
mod toast;

use anyhow::Result;
use cli::Args;

fn main() {
    if let Err(e) = run() {
        eprintln!("\x1b[1;31m[ERROR]\x1b[0m {}", e);
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let args = Args::parse_args();

    // 处理 --init
    if args.init {
        println!("\x1b[1;32m[INFO]\x1b[0m Registering AUMID and creating Start Menu shortcut...");
        registration::register()?;
        println!("\x1b[1;32m[INFO]\x1b[0m Registration complete!");
        return Ok(());
    }

    // 处理 --uninstall
    if args.uninstall {
        println!("\x1b[1;32m[INFO]\x1b[0m Removing registration...");
        registration::unregister()?;
        println!("\x1b[1;32m[INFO]\x1b[0m Unregistration complete!");
        return Ok(());
    }

    // 检查是否已注册
    if !registration::is_registered() {
        eprintln!("\x1b[1;33m[WARN]\x1b[0m Not registered. Run with --init first for proper notifications.");
    }

    // 决定是否静音
    let silent = args.no_sound || args.sound_file.is_some();

    // 发送通知
    toast::send_notification(&args.title, &args.message, silent)?;

    // 播放自定义音效
    if let Some(ref sound_file) = args.sound_file {
        sound::play_sound_file(sound_file)?;
    }

    Ok(())
}
