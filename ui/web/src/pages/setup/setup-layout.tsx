import { useTranslation } from "react-i18next";

export function SetupLayout({ children }: { children: React.ReactNode }) {
  const { t } = useTranslation("setup");

  return (
    <div className="flex min-h-dvh items-start justify-center bg-background px-4 py-8 sm:items-center">
      <div className="w-full max-w-2xl space-y-6 overflow-y-auto max-h-dvh sm:max-h-none">
        <div className="text-center">
          <img src="/raifirst-logo.webp" alt="RAIFIRST" className="raifirst-logo mx-auto mb-6 h-auto w-64 max-w-full" />
          <h1 className="text-4xl font-bold tracking-tight">RAIFIRST AI</h1>
          <p className="mt-2 text-sm text-muted-foreground">
            {t("layout.subtitle", "Let's get your gateway up and running")}
          </p>
        </div>
        {children}
      </div>
    </div>
  );
}
