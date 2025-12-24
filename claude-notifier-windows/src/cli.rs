use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "claude-notifier")]
#[command(about = "Windows native notification tool for Claude Code")]
#[command(version)]
pub struct Args {
    /// Notification title
    #[arg(short = 't', long, default_value = "Claude Code")]
    pub title: String,

    /// Notification message
    #[arg(short = 'm', long, default_value = "Task completed")]
    pub message: String,

    /// System sound name (e.g., "Notification.Default")
    #[arg(short = 's', long)]
    pub sound: Option<String>,

    /// Custom sound file path (.wav)
    #[arg(short = 'f', long = "sound-file")]
    pub sound_file: Option<String>,

    /// Disable notification sound
    #[arg(long = "no-sound")]
    pub no_sound: bool,

    /// First-run: register AUMID and create Start Menu shortcut
    #[arg(long)]
    pub init: bool,

    /// Remove registration and clean up
    #[arg(long)]
    pub uninstall: bool,
}

impl Args {
    pub fn parse_args() -> Self {
        Self::parse()
    }
}
