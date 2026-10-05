//! Provider credentials stay in the OS vault, never in IPC settings or logs.
use std::collections::HashMap;

const SERVICE: &str = "com.nathanielschool.nsmflow.post-processing";

fn entry(provider: &str) -> Result<keyring::Entry, String> {
    keyring::Entry::new(SERVICE, provider)
        .map_err(|_| "Could not open the operating system credential store".to_string())
}

pub fn get(provider: &str) -> Result<String, String> {
    match entry(provider)?.get_password() {
        Ok(secret) => Ok(secret),
        Err(keyring::Error::NoEntry) => Ok(String::new()),
        Err(_) => Err("Unlock the operating system credential store and try again".to_string()),
    }
}

pub fn set(provider: &str, secret: &str) -> Result<(), String> {
    let entry = entry(provider)?;
    if secret.is_empty() {
        match entry.delete_credential() {
            Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
            Err(_) => Err("Could not remove the credential from the operating system store".into()),
        }
    } else {
        entry.set_password(secret).map_err(|_| {
            "Could not save the credential. Unlock the operating system store and retry".into()
        })
    }
}

/// Erase a legacy value only after saving and reading it back successfully.
/// Failed migrations retain the user's existing credential for a later retry.
pub fn migrate_legacy<F>(keys: &mut HashMap<String, String>, mut save: F) -> bool
where
    F: FnMut(&str, &str) -> Result<(), String>,
{
    let mut changed = false;
    for (provider, secret) in keys.iter_mut().filter(|(_, secret)| !secret.is_empty()) {
        if save(provider, secret).is_ok() {
            secret.clear();
            changed = true;
        } else {
            log::warn!(
                "Credential migration is pending for provider {}: unlock the OS vault and restart",
                provider
            );
        }
    }
    changed
}

pub fn migrate(keys: &mut HashMap<String, String>) -> bool {
    migrate_legacy(keys, |provider, secret| {
        set(provider, secret)?;
        if get(provider)? != secret {
            return Err("Credential verification failed".into());
        }
        Ok(())
    })
}

/// Legacy fallback is restricted to migration failures; new keys never use it.
pub fn for_provider(provider: &str, legacy: &HashMap<String, String>) -> Result<String, String> {
    match get(provider) {
        Ok(secret) if !secret.is_empty() => Ok(secret),
        result => match legacy.get(provider).filter(|secret| !secret.is_empty()) {
            Some(secret) => Ok(secret.clone()),
            None => result,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn migration_erases_only_verified_credentials_and_retries_failures() {
        let mut keys = HashMap::from([
            ("good".into(), "first".into()),
            ("locked".into(), "second".into()),
        ]);
        assert!(migrate_legacy(&mut keys, |provider, _| {
            if provider == "good" {
                Ok(())
            } else {
                Err("locked".into())
            }
        }));
        assert_eq!(keys["good"], "");
        assert_eq!(keys["locked"], "second");
        let mut retried = Vec::new();
        assert!(migrate_legacy(&mut keys, |provider, _| {
            retried.push(provider.to_string());
            Ok(())
        }));
        assert_eq!(retried, vec!["locked"]);
        assert!(!migrate_legacy(&mut keys, |_, _| panic!(
            "Already migrated"
        )));
    }
}
