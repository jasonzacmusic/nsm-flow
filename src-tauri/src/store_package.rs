//! Microsoft Store (MSIX) install detection.
//!
//! Windows installs Store packages under `...\WindowsApps\`. In that install the
//! Store owns updates, and start-at-login goes through the package's
//! `StartupTask` (declared in `store/AppxManifest.xml`) because writes to the
//! registry's Run key are redirected into the package and never take effect.

use std::sync::OnceLock;

/// Must match `TaskId` of the `windows.startupTask` extension in the manifest.
#[cfg(windows)]
const STARTUP_TASK_ID: &str = "NSMFlowStartup";

static IS_STORE_PACKAGE: OnceLock<bool> = OnceLock::new();

/// Returns `true` when running from a Microsoft Store (MSIX) package.
pub fn is_store_package() -> bool {
    *IS_STORE_PACKAGE.get_or_init(|| {
        if !cfg!(windows) {
            return false;
        }
        std::env::current_exe()
            .map(|exe| {
                exe.to_string_lossy()
                    .to_ascii_lowercase()
                    .contains("\\windowsapps\\")
            })
            .unwrap_or(false)
    })
}

/// Turns the package's start-at-login task on or off. Runs on its own thread
/// because the WinRT calls block until Windows answers.
#[cfg(windows)]
pub fn set_start_at_login(enabled: bool) {
    std::thread::spawn(move || {
        use windows::core::HSTRING;
        use windows::ApplicationModel::{StartupTask, StartupTaskState};
        use windows::Win32::System::WinRT::{RoInitialize, RO_INIT_MULTITHREADED};

        let _ = unsafe { RoInitialize(RO_INIT_MULTITHREADED) };
        let result = (|| -> windows::core::Result<StartupTaskState> {
            let task = StartupTask::GetAsync(&HSTRING::from(STARTUP_TASK_ID))?.get()?;
            if enabled {
                if task.State()? == StartupTaskState::Disabled {
                    return task.RequestEnableAsync()?.get();
                }
            } else {
                task.Disable()?;
            }
            task.State()
        })();
        match result {
            Ok(state) => log::info!("Store start-at-login task is now {:?}", state),
            Err(e) => log::warn!("Could not change Store start-at-login task: {}", e),
        }
    });
}

#[cfg(not(windows))]
pub fn set_start_at_login(_enabled: bool) {}
