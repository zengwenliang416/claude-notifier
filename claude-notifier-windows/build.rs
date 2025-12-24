#[cfg(windows)]
fn main() {
    // 嵌入图标资源（如果存在 resources/app.rc）
    let rc_path = std::path::Path::new("resources/app.rc");
    if rc_path.exists() {
        embed_resource::compile("resources/app.rc", embed_resource::NONE);
    }
}

#[cfg(not(windows))]
fn main() {
    // 非 Windows 平台无需嵌入资源
}
