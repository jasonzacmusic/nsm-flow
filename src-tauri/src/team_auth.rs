use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use rand::{rngs::OsRng, RngCore};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use specta::Type;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::thread;
use std::time::{Duration, Instant};
use tauri::AppHandle;
use tauri_plugin_opener::OpenerExt;
use tauri_plugin_store::StoreExt;
use url::Url;

const TEAM_STORE_PATH: &str = "team.json";
const TEAM_MEMBER_KEY: &str = "member";
const SIGN_IN_TIMEOUT: Duration = Duration::from_secs(180);

#[derive(Clone, Debug, Deserialize, Serialize, Type)]
pub struct TeamMember {
    pub email: String,
    pub name: String,
}

#[derive(Clone, Debug, Serialize, Type)]
pub struct TeamAuthStatus {
    pub configured: bool,
    pub allowed_domain: Option<String>,
}

#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
}

#[derive(Debug, Deserialize)]
struct GoogleUserInfo {
    email: String,
    name: Option<String>,
    email_verified: Option<bool>,
}

fn google_client_id() -> Option<String> {
    std::env::var("NSM_FLOW_GOOGLE_CLIENT_ID")
        .ok()
        .or_else(|| option_env!("NSM_FLOW_GOOGLE_CLIENT_ID").map(str::to_owned))
        .filter(|value| !value.trim().is_empty())
}

fn allowed_domain() -> Option<String> {
    std::env::var("NSM_FLOW_ALLOWED_EMAIL_DOMAIN")
        .ok()
        .or_else(|| option_env!("NSM_FLOW_ALLOWED_EMAIL_DOMAIN").map(str::to_owned))
        .map(|value| value.trim().trim_start_matches('@').to_ascii_lowercase())
        .filter(|value| !value.is_empty())
}

fn random_url_safe(bytes: usize) -> String {
    let mut value = vec![0_u8; bytes];
    OsRng.fill_bytes(&mut value);
    URL_SAFE_NO_PAD.encode(value)
}

fn save_member(app: &AppHandle, member: &TeamMember) -> Result<(), String> {
    let store = app
        .store(crate::portable::store_path(TEAM_STORE_PATH))
        .map_err(|error| format!("Could not open the local team profile: {error}"))?;
    store.set(
        TEAM_MEMBER_KEY,
        serde_json::to_value(member)
            .map_err(|error| format!("Could not save the local team profile: {error}"))?,
    );
    store
        .save()
        .map_err(|error| format!("Could not save the local team profile: {error}"))
}

#[tauri::command]
#[specta::specta]
pub fn get_team_auth_status() -> TeamAuthStatus {
    TeamAuthStatus {
        configured: google_client_id().is_some(),
        allowed_domain: allowed_domain(),
    }
}

#[tauri::command]
#[specta::specta]
pub fn get_team_member(app: AppHandle) -> Result<Option<TeamMember>, String> {
    let store = app
        .store(crate::portable::store_path(TEAM_STORE_PATH))
        .map_err(|error| format!("Could not open the local team profile: {error}"))?;

    match store.get(TEAM_MEMBER_KEY) {
        Some(value) => serde_json::from_value(value.clone())
            .map(Some)
            .map_err(|error| format!("Could not read the local team profile: {error}")),
        None => Ok(None),
    }
}

#[tauri::command]
#[specta::specta]
pub fn sign_out_team_member(app: AppHandle) -> Result<(), String> {
    let store = app
        .store(crate::portable::store_path(TEAM_STORE_PATH))
        .map_err(|error| format!("Could not open the local team profile: {error}"))?;
    store.delete(TEAM_MEMBER_KEY);
    store
        .save()
        .map_err(|error| format!("Could not update the local team profile: {error}"))
}

fn wait_for_callback(listener: TcpListener, expected_state: String) -> Result<String, String> {
    listener
        .set_nonblocking(true)
        .map_err(|error| format!("Could not prepare the Google sign-in callback: {error}"))?;

    let started = Instant::now();
    while started.elapsed() < SIGN_IN_TIMEOUT {
        match listener.accept() {
            Ok((mut stream, _)) => {
                stream
                    .set_read_timeout(Some(Duration::from_secs(5)))
                    .map_err(|error| format!("Could not read the sign-in callback: {error}"))?;

                let mut request = [0_u8; 8192];
                let bytes_read = stream
                    .read(&mut request)
                    .map_err(|error| format!("Could not read the sign-in callback: {error}"))?;
                let request = String::from_utf8_lossy(&request[..bytes_read]);
                let target = request
                    .lines()
                    .next()
                    .and_then(|line| line.split_whitespace().nth(1))
                    .ok_or_else(|| "Google returned an invalid sign-in callback.".to_string())?;
                let callback = Url::parse(&format!("http://127.0.0.1{target}"))
                    .map_err(|error| format!("Google returned an invalid callback URL: {error}"))?;
                let params: std::collections::HashMap<String, String> =
                    callback.query_pairs().into_owned().collect();

                let response_body = if params.contains_key("error") {
                    "NSM Flow sign-in was cancelled. You can close this tab."
                } else {
                    "You are signed in to NSM Flow. You can close this tab."
                };
                let html = format!("<!doctype html><title>NSM Flow</title><p>{response_body}</p>");
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{html}",
                    html.len()
                );
                let _ = stream.write_all(response.as_bytes());
                let _ = stream.flush();

                if let Some(error) = params.get("error") {
                    return Err(format!("Google sign-in was not completed: {error}"));
                }
                if params.get("state") != Some(&expected_state) {
                    return Err("Google sign-in validation failed. Please try again.".to_string());
                }
                return params
                    .get("code")
                    .cloned()
                    .ok_or_else(|| "Google did not return an authorization code.".to_string());
            }
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                thread::sleep(Duration::from_millis(100));
            }
            Err(error) => {
                return Err(format!(
                    "Could not receive the Google sign-in callback: {error}"
                ));
            }
        }
    }

    Err("Google sign-in timed out. Please try again.".to_string())
}

#[tauri::command]
#[specta::specta]
pub async fn google_sign_in(app: AppHandle) -> Result<TeamMember, String> {
    let client_id = google_client_id().ok_or_else(|| {
        "Google sign-in is not configured in this build yet. The NSM administrator needs to add the desktop OAuth client ID.".to_string()
    })?;

    let listener = TcpListener::bind("127.0.0.1:0")
        .map_err(|error| format!("Could not start the local sign-in callback: {error}"))?;
    let port = listener
        .local_addr()
        .map_err(|error| format!("Could not read the local sign-in address: {error}"))?
        .port();
    let redirect_uri = format!("http://127.0.0.1:{port}/oauth/callback");

    let verifier = random_url_safe(64);
    let challenge = URL_SAFE_NO_PAD.encode(Sha256::digest(verifier.as_bytes()));
    let state = random_url_safe(32);
    let mut authorization_url = Url::parse("https://accounts.google.com/o/oauth2/v2/auth")
        .map_err(|error| format!("Could not prepare Google sign-in: {error}"))?;
    authorization_url
        .query_pairs_mut()
        .append_pair("client_id", &client_id)
        .append_pair("redirect_uri", &redirect_uri)
        .append_pair("response_type", "code")
        .append_pair("scope", "openid email profile")
        .append_pair("code_challenge", &challenge)
        .append_pair("code_challenge_method", "S256")
        .append_pair("state", &state)
        .append_pair("prompt", "select_account");

    app.opener()
        .open_url(authorization_url.as_str(), None::<String>)
        .map_err(|error| format!("Could not open Google sign-in: {error}"))?;

    let code = tauri::async_runtime::spawn_blocking(move || wait_for_callback(listener, state))
        .await
        .map_err(|error| format!("Google sign-in was interrupted: {error}"))??;

    let client = reqwest::Client::new();
    let token: TokenResponse = client
        .post("https://oauth2.googleapis.com/token")
        .form(&[
            ("client_id", client_id.as_str()),
            ("code", code.as_str()),
            ("code_verifier", verifier.as_str()),
            ("grant_type", "authorization_code"),
            ("redirect_uri", redirect_uri.as_str()),
        ])
        .send()
        .await
        .map_err(|error| format!("Could not reach Google sign-in: {error}"))?
        .error_for_status()
        .map_err(|error| format!("Google rejected the sign-in: {error}"))?
        .json()
        .await
        .map_err(|error| format!("Could not read Google's sign-in response: {error}"))?;

    let profile: GoogleUserInfo = client
        .get("https://openidconnect.googleapis.com/v1/userinfo")
        .bearer_auth(&token.access_token)
        .send()
        .await
        .map_err(|error| format!("Could not fetch the Google profile: {error}"))?
        .error_for_status()
        .map_err(|error| format!("Google rejected the profile request: {error}"))?
        .json()
        .await
        .map_err(|error| format!("Could not read the Google profile: {error}"))?;

    if profile.email_verified != Some(true) {
        return Err("Please use a verified Google account.".to_string());
    }
    if let Some(domain) = allowed_domain() {
        let actual_domain = profile
            .email
            .rsplit_once('@')
            .map(|(_, value)| value.to_ascii_lowercase());
        if actual_domain.as_deref() != Some(domain.as_str()) {
            return Err(format!("Please sign in with an @{domain} Google account."));
        }
    }

    let member = TeamMember {
        name: profile.name.unwrap_or_else(|| profile.email.clone()),
        email: profile.email,
    };
    save_member(&app, &member)?;
    Ok(member)
}
