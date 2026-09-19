// Header control for choosing the app icon. A small menu of radio items.

import { useEffect, useRef, useState } from "react";
import { Check, ChevronDown } from "lucide-react";
import { APP_ICONS } from "../lib/appIcons";

interface Props {
  value: string;
  onChange: (id: string) => void;
}

export function AppIconPicker({ value, onChange }: Props) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const itemRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const current = APP_ICONS.find((i) => i.id === value) ?? APP_ICONS[0];

  useEffect(() => {
    if (!open) return;
    itemRefs.current[Math.max(0, APP_ICONS.findIndex((i) => i.id === value))]?.focus();
    const onPointer = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", onPointer);
    return () => document.removeEventListener("pointerdown", onPointer);
  }, [open, value]);

  const onMenuKey = (e: React.KeyboardEvent, index: number) => {
    if (e.key === "Escape") {
      setOpen(false);
      rootRef.current?.querySelector<HTMLButtonElement>("button")?.focus();
    } else if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      const next = (index + (e.key === "ArrowDown" ? 1 : -1) + APP_ICONS.length) % APP_ICONS.length;
      itemRefs.current[next]?.focus();
    }
  };

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={`App icon: ${current.name}`}
        title="App icon"
        className="flex h-9 items-center gap-1 rounded-md border border-line-strong pr-1.5 pl-1 transition-colors hover:bg-raised"
      >
        <img src={current.thumb} alt="" className="size-7" />
        <ChevronDown size={14} className="text-muted" />
      </button>

      {open && (
        <div
          role="menu"
          aria-label="App icon"
          className="pop absolute top-full right-0 z-40 mt-2 w-56 rounded-lg border border-line bg-surface p-1.5 shadow-2xl"
        >
          <p className="px-2 pt-1 pb-1.5 text-[12px] text-muted">App icon</p>
          {APP_ICONS.map((icon, i) => {
            const selected = icon.id === current.id;
            return (
              <button
                key={icon.id}
                ref={(el) => {
                  itemRefs.current[i] = el;
                }}
                type="button"
                role="menuitemradio"
                aria-checked={selected}
                onKeyDown={(e) => onMenuKey(e, i)}
                onClick={() => {
                  onChange(icon.id);
                  setOpen(false);
                }}
                className={
                  "flex w-full items-center gap-2.5 rounded-md px-2 py-1.5 text-left text-[13px] font-semibold outline-none hover:bg-raised focus-visible:bg-raised " +
                  (selected ? "text-ink" : "text-muted")
                }
              >
                <img src={icon.thumb} alt="" className="size-9" />
                <span className="flex-1">{icon.name}</span>
                {selected && <Check size={15} className="text-good" />}
              </button>
            );
          })}
          <p className="px-2 pt-1.5 pb-1 text-[11px] leading-snug text-muted">
            Changes the Dock or taskbar icon while the app is open.
          </p>
        </div>
      )}
    </div>
  );
}
