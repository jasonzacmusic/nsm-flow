import React from "react";
import { useTranslation } from "react-i18next";
import { Dropdown } from "../ui/Dropdown";
import { SettingContainer } from "../ui/SettingContainer";
import { useSettings } from "../../hooks/useSettings";
import { RecordingRetentionPeriod } from "@/bindings";

interface RecordingRetentionPeriodProps {
  descriptionMode?: "inline" | "tooltip";
  grouped?: boolean;
  transcript?: boolean;
}

export const RecordingRetentionPeriodSelector: React.FC<RecordingRetentionPeriodProps> =
  React.memo(
    ({ descriptionMode = "tooltip", grouped = false, transcript = false }) => {
      const { t } = useTranslation();
      const { getSetting, updateSetting, isUpdating } = useSettings();

      const setting = transcript
        ? "transcript_retention_period"
        : "recording_retention_period";
      const selectedRetentionPeriod = getSetting(setting) || "never";
      const historyLimit = getSetting("history_limit") || 5;

      const handleRetentionPeriodSelect = async (period: string) => {
        await updateSetting(setting, period as RecordingRetentionPeriod);
      };

      const retentionOptions = [
        {
          value: "delete_immediately",
          label: t(
            transcript
              ? "settings.history.transcriptRetention.deleteImmediately"
              : "settings.debug.recordingRetention.deleteImmediately",
          ),
        },
        { value: "never", label: t("settings.debug.recordingRetention.never") },
        {
          value: "preserve_limit",
          label: t("settings.debug.recordingRetention.preserveLimit", {
            count: Number(historyLimit),
          }),
        },
        { value: "days3", label: t("settings.debug.recordingRetention.days3") },
        {
          value: "weeks2",
          label: t("settings.debug.recordingRetention.weeks2"),
        },
        {
          value: "months3",
          label: t("settings.debug.recordingRetention.months3"),
        },
      ];

      return (
        <SettingContainer
          title={t(
            transcript
              ? "settings.history.transcriptRetention.title"
              : "settings.debug.recordingRetention.title",
          )}
          description={t(
            transcript
              ? "settings.history.transcriptRetention.description"
              : "settings.debug.recordingRetention.description",
          )}
          descriptionMode={descriptionMode}
          grouped={grouped}
        >
          <Dropdown
            options={retentionOptions}
            selectedValue={selectedRetentionPeriod}
            onSelect={handleRetentionPeriodSelect}
            placeholder={t("settings.debug.recordingRetention.placeholder")}
            disabled={isUpdating(setting)}
          />
        </SettingContainer>
      );
    },
  );

RecordingRetentionPeriodSelector.displayName =
  "RecordingRetentionPeriodSelector";
