use flate2::read::GzDecoder;
use std::{
    fs, io,
    path::{Path, PathBuf},
};
fn main() -> io::Result<()> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 3 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "usage: updater-archive-check ARCHIVE EMPTY_APP_DIRECTORY",
        ));
    }
    let destination = Path::new(&args[2]);
    fs::create_dir_all(destination)?;
    let mut archive = tar::Archive::new(GzDecoder::new(fs::File::open(&args[1])?));
    for entry in archive.entries()? {
        let mut entry = entry?;
        let original = entry.path()?.to_path_buf();
        if original.components().next().map(|c| c.as_os_str())
            != Some(std::ffi::OsStr::new("NSM Flow.app"))
            || original.components().any(|c| {
                matches!(
                    c,
                    std::path::Component::ParentDir
                        | std::path::Component::RootDir
                        | std::path::Component::Prefix(_)
                )
            })
            || original
                .components()
                .any(|c| c.as_os_str().to_string_lossy().starts_with("._"))
        {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "Unexpected root, AppleDouble metadata, or unsafe archive path",
            ));
        }
        let stripped: PathBuf = original.iter().skip(1).collect();
        let target = destination.join(stripped);
        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent)?;
        }
        if let Err(error) = entry.unpack(&target) {
            eprintln!("Updater entry {:?} -> {:?}: {}", original, target, error);
            return Err(error);
        }
    }
    println!("All entries extracted with Tauri updater's macOS algorithm");
    Ok(())
}
