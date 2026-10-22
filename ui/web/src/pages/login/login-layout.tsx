import { Moon, Sun } from "lucide-react";
import { useTranslation } from "react-i18next";
import { useUiStore } from "@/stores/use-ui-store";

interface LoginLayoutProps {
  children: React.ReactNode;
  subtitle?: string;
}

export function LoginLayout({ children, subtitle }: LoginLayoutProps) {
  const { t } = useTranslation("topbar");
  const theme = useUiStore((s) => s.theme);
  const setTheme = useUiStore((s) => s.setTheme);
  const isDark =
    theme === "dark" ||
    (theme === "system" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches);

  return (
    <div className="relative flex h-dvh items-start justify-center overflow-y-auto bg-background px-4 py-8">
      <button
        type="button"
        onClick={() => setTheme(isDark ? "light" : "dark")}
        className="absolute top-4 right-4 cursor-pointer rounded-md border bg-card p-2 text-muted-foreground shadow-sm transition-colors hover:bg-accent hover:text-accent-foreground"
        title={t("toggleTheme")}
        aria-label={t("toggleTheme")}
      >
        {isDark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
      </button>
      <div className="my-auto w-full max-w-sm shrink-0 space-y-6 rounded-lg border bg-card p-6 shadow-sm sm:p-8">
        <div className="space-y-3 text-center">
          <h1>
            <img src="/raifirst-logo.webp" alt="RAIFIRST" width={1672} height={351} className="raifirst-logo mx-auto h-auto w-40 max-w-full sm:w-44" />
          </h1>
          {subtitle && (
            <p className="text-sm text-muted-foreground">{subtitle}</p>
          )}
        </div>
        {children}
      </div>
    </div>
  );
}
