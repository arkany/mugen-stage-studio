interface Props {
  step: number;
  title: string;
  subtitle: string;
  id?: string;
}

export function SectionHeading({ step, title, subtitle, id }: Props) {
  return (
    <div className="mb-3 flex items-start gap-3">
      <span className="grid size-8 shrink-0 -skew-x-6 place-items-center rounded-md bg-p1-fill font-display text-xl leading-none text-white">
        {step}
      </span>
      <div>
        <h2 id={id} className="text-[17px] font-bold leading-tight">
          {title}
        </h2>
        <p className="mt-0.5 text-[13px] text-muted">{subtitle}</p>
      </div>
    </div>
  );
}
