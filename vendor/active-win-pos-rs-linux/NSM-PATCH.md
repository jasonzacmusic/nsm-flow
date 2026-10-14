# Linux-only window backend

Source: active-win-pos-rs 0.10.0 from crates.io, by Dmitry Malkov.
License: MIT OR Apache-2.0, as declared by upstream. The archive includes both license texts.

NSM changes: permit the compatible kdotool 0.2.3 dependency with CLI-only default features disabled and omit example/readme entries that are not distributed here. Runtime source is unchanged.

This target-only path dependency retains X11/KDE detection without the GPL Hyprland helper introduced in 0.11. Mac/Windows still use the registry 0.11.0 package. Revisit when upstream provides an optional Hyprland feature.
