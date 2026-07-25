import { useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { ShieldCheck, UserRoundCheck } from "lucide-react";
import { useTranslation } from "react-i18next";
import { Button } from "../../ui/Button";
import { SettingContainer } from "../../ui/SettingContainer";
import { SettingsGroup } from "../../ui/SettingsGroup";

interface TeamMember {
  email: string;
  name: string;
}

interface TeamAuthStatus {
  configured: boolean;
  allowed_domain: string | null;
}

export const TeamSettings = () => {
  const { t } = useTranslation();
  const [member, setMember] = useState<TeamMember | null>(null);
  const [status, setStatus] = useState<TeamAuthStatus | null>(null);
  const [working, setWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([
      invoke<TeamMember | null>("get_team_member"),
      invoke<TeamAuthStatus>("get_team_auth_status"),
    ])
      .then(([currentMember, authStatus]) => {
        setMember(currentMember);
        setStatus(authStatus);
      })
      .catch((reason: unknown) => {
        setError(String(reason));
      });
  }, []);

  const signIn = async () => {
    setWorking(true);
    setError(null);
    try {
      setMember(await invoke<TeamMember>("google_sign_in"));
    } catch (reason) {
      setError(String(reason));
    } finally {
      setWorking(false);
    }
  };

  const signOut = async () => {
    setWorking(true);
    setError(null);
    try {
      await invoke("sign_out_team_member");
      setMember(null);
    } catch (reason) {
      setError(String(reason));
    } finally {
      setWorking(false);
    }
  };

  return (
    <div className="max-w-3xl w-full mx-auto space-y-6">
      <SettingsGroup
        title={t("settings.team.title")}
        description={t("settings.team.description")}
      >
        <SettingContainer
          title={t("settings.team.account.title")}
          description={t("settings.team.account.description")}
          grouped={true}
          layout="stacked"
        >
          {member ? (
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-3 min-w-0">
                <UserRoundCheck className="w-5 h-5 text-logo-primary shrink-0" />
                <div className="min-w-0">
                  <p className="text-sm font-medium truncate">{member.name}</p>
                  <p className="text-xs text-mid-gray truncate">
                    {member.email}
                  </p>
                </div>
              </div>
              <Button variant="secondary" onClick={signOut} disabled={working}>
                {t("settings.team.account.signOut")}
              </Button>
            </div>
          ) : (
            <div className="space-y-2">
              <Button
                variant="primary"
                onClick={signIn}
                disabled={working || status?.configured === false}
              >
                {working
                  ? t("settings.team.account.working")
                  : t("settings.team.account.signIn")}
              </Button>
              {status?.configured === false && (
                <p className="text-xs text-amber-500">
                  {t("settings.team.account.notConfigured")}
                </p>
              )}
            </div>
          )}
          {error && <p className="text-xs text-red-500 mt-2">{error}</p>}
        </SettingContainer>
      </SettingsGroup>

      <SettingsGroup title={t("settings.team.privacy.title")}>
        <SettingContainer
          title={t("settings.team.privacy.local.title")}
          description={t("settings.team.privacy.local.description")}
          grouped={true}
          layout="stacked"
        >
          <div className="flex items-center gap-2 text-sm text-mid-gray">
            <ShieldCheck className="w-5 h-5 text-emerald-500" />
            <span>{t("settings.team.privacy.local.status")}</span>
          </div>
        </SettingContainer>
      </SettingsGroup>
    </div>
  );
};
