import { Check, Moon, PanelRight, Sun } from "lucide-react";
import { shortcutLabel } from "../lib/platform";
import logoDark from "../assets/logo-ink-dark.webp";
import logoLight from "../assets/logo-ink-light.webp";

export type StepId = 1 | 2 | 3;
export type Theme = "light" | "dark";

interface Props {
  currentStep: StepId;
  completed: Record<StepId, boolean>;
  onStepClick: (step: StepId) => void;
  detailsOpen: boolean;
  onToggleDetails: () => void;
  theme: Theme;
  onToggleTheme: () => void;
}

const STEPS: { id: StepId; label: string }[] = [
  { id: 1, label: "Resolution" },
  { id: 2, label: "Image" },
  { id: 3, label: "Export" },
];

export function Header({
  currentStep,
  completed,
  onStepClick,
  detailsOpen,
  onToggleDetails,
  theme,
  onToggleTheme,
}: Props) {
  return (
    <header className="flex shrink-0 items-center gap-6 border-b border-line bg-surface px-5 py-2">
      <div className="flex items-center gap-4">
        <Wordmark theme={theme} />
        <p className="hidden max-w-[12rem] text-[13px] leading-snug text-muted xl:block">
          Turn any image into a fighting stage
        </p>
      </div>

      <nav aria-label="Steps" className="mx-auto">
        <ol className="flex items-center gap-1">
          {STEPS.map((step, i) => {
            const active = step.id === currentStep;
            const done = completed[step.id] && !active;
            return (
              <li key={step.id} className="flex items-center gap-1">
                {i > 0 && <span aria-hidden className="h-px w-6 bg-line-strong" />}
                <button
                  type="button"
                  onClick={() => onStepClick(step.id)}
                  aria-current={active ? "step" : undefined}
                  className={
                    "flex items-center gap-2 rounded-full py-1.5 pr-4 pl-1.5 text-sm font-semibold transition-colors " +
                    (active
                      ? "bg-p1-soft text-ink"
                      : "text-muted hover:bg-raised hover:text-ink")
                  }
                >
                  <span
                    className={
                      "grid size-7 place-items-center rounded-full text-sm font-bold " +
                      (active
                        ? "bg-p1-fill text-white"
                        : done
                          ? "bg-good-soft text-good"
                          : "bg-raised text-muted")
                    }
                  >
                    {done ? <Check size={15} strokeWidth={3} /> : step.id}
                  </span>
                  {step.label}
                </button>
              </li>
            );
          })}
        </ol>
      </nav>

      <button
        type="button"
        onClick={onToggleTheme}
        aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} mode`}
        title={`Switch to ${theme === "dark" ? "light" : "dark"} mode`}
        className="grid size-9 place-items-center rounded-md border border-line-strong text-ink transition-colors hover:bg-raised"
      >
        {theme === "dark" ? <Sun size={16} /> : <Moon size={16} />}
      </button>

      <button
        type="button"
        onClick={onToggleDetails}
        aria-pressed={detailsOpen}
        title={`Show every engine value (${shortcutLabel("I")})`}
        className={
          "flex items-center gap-2 rounded-md border px-3 py-2 text-[13px] font-semibold transition-colors " +
          (detailsOpen
            ? "border-p2 bg-p2-soft text-ink"
            : "border-line-strong text-ink hover:bg-raised")
        }
      >
        <PanelRight size={16} />
        {detailsOpen ? "Hide details" : "Show details"}
      </button>
    </header>
  );
}

function Wordmark({ theme }: { theme: Theme }) {
  return (
    <img
      src={theme === "dark" ? logoDark : logoLight}
      alt="MUGEN Stage Studio"
      draggable={false}
      className="h-14 w-auto shrink-0 select-none"
    />
  );
}
