import type { Page } from "@playwright/test";

/** Native IPC fixture for UI contracts. Audio/OS acceptance uses the signed app. */
export async function mockDesktop(page: Page, withUpdate = false) {
  await page.addInitScript((withUpdate) => {
    const state = {
      confirm: false,
      failRetention: false,
      keyWrites: [] as string[],
      updateCalls: [] as string[],
      updateDialogs: [] as any[],
      updateBusy: false,
      updateDownloadFails: false,
      settings: {
        onboarding_completed: true,
        app_language: "en",
        theme: "light",
        selected_model: "small",
        bindings: {},
        post_process_enabled: true,
        update_checks_enabled: withUpdate,
        show_whats_new_on_update: false,
        recording_retention_period: "delete_immediately",
        transcript_retention_period: "never",
        history_limit: 5,
        post_process_provider_id: "openai",
        post_process_api_keys: { openai: "[CONFIGURED]" },
        post_process_models: { openai: "test-model" },
        post_process_prompts: [],
        post_process_providers: [
          {
            id: "openai",
            label: "OpenAI",
            base_url: "https://api.openai.com/v1",
            supports_cancellation: true,
          },
        ],
        audio_feedback: false,
        always_on_microphone: false,
        custom_words: [],
        selected_language: "auto",
      },
      entries: [
        {
          id: 1,
          file_name: "",
          saved: true,
          title: "Music lesson",
          timestamp: 1791150000,
          transcription_text: "Play the C major scale",
          post_process_requested: false,
          post_processed_text: null,
          post_process_prompt: null,
        },
      ],
    };
    const callbacks: Record<number, Function> = {};
    let next = 1;
    Object.assign(window, {
      __desktop: state,
      __TAURI_OS_PLUGIN_INTERNALS__: {
        platform: "macos",
        os_type: "macos",
        arch: "aarch64",
        family: "unix",
        version: "26.0",
        eol: "\n",
      },
      __TAURI_INTERNALS__: {
        metadata: {
          currentWindow: { label: "main" },
          currentWebview: { label: "main" },
        },
        convertFileSrc: (path: string) => path,
        transformCallback: (callback: Function) => {
          const id = next++;
          callbacks[id] = callback;
          return id;
        },
        unregisterCallback: (id: number) => {
          delete callbacks[id];
        },
        invoke: async (command: string, args: any = {}) => {
          state.updateCalls.push(command);
          if (command === "plugin:updater|check")
            return withUpdate
              ? {
                  rid: 1,
                  currentVersion: "0.3.0-alpha.3",
                  version: "0.3.0-alpha.4",
                  body: "Release fixture: clearer classroom notation",
                  rawJson: {},
                }
              : null;
          if (command === "begin_application_update") {
            if (state.updateBusy)
              throw "Finish your recording or transcription before updating.";
            return null;
          }
          if (command === "plugin:updater|download_and_install") {
            if (state.updateDownloadFails) throw "Download unavailable";
            return null;
          }
          if (
            command === "get_app_settings" ||
            command === "get_default_settings"
          )
            return JSON.parse(JSON.stringify(state.settings));
          if (command === "get_available_models") return [];
          if (command === "get_current_model") return "small";
          if (command === "get_history_entries")
            return { entries: state.entries, has_more: false };
          if (command === "clear_history") {
            state.entries = [];
            return null;
          }
          if (command === "update_transcript_retention_period") {
            if (state.failRetention) throw "Disk unavailable";
            state.settings.transcript_retention_period = args.period;
            return null;
          }
          if (command === "change_post_process_api_key_setting") {
            state.keyWrites.push(args.apiKey);
            return null;
          }
          if (command.startsWith("plugin:dialog|")) {
            state.updateDialogs.push({ command, args });
            return state.confirm;
          }
          if (
            command.includes("check_accessibility") ||
            command.includes("check_microphone")
          )
            return true;
          if (
            command === "get_available_microphones" ||
            command === "get_available_output_devices" ||
            command === "fetch_post_process_models"
          )
            return [];
          if (command === "check_custom_sounds")
            return { start: false, stop: false };
          if (command === "get_team_auth_status")
            return { configured: false, signed_in: false, member: null };
          if (command === "get_team_member") return null;
          if (command === "get_transcription_model_status")
            return { is_loaded: false, is_loading: false };
          if (command === "plugin:app|version") return "0.3.0-alpha.3";
          if (command === "plugin:app|name") return "NSM Flow";
          if (command === "plugin:event|listen") return next++;
          return null;
        },
      },
    });
  }, withUpdate);
}
