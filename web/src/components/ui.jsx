import { useEffect, useId, useRef, useState } from 'react';

export function Card({ children, tint, className = '' }) {
  const style = tint ? { '--tint': tint } : undefined;
  return (
    <section className={`card ${tint ? 'card--tinted' : ''} ${className}`} style={style}>
      {children}
    </section>
  );
}

export function SectionTitle({ title, subtitle }) {
  return (
    <div className="section-title">
      <h3>{title}</h3>
      {subtitle && <p className="muted">{subtitle}</p>}
    </div>
  );
}

export function Pill({ children, variant }) {
  return <span className={`pill ${variant ? `pill--${variant}` : ''}`}>{children}</span>;
}

// Safety copy is deliberately styled apart from the motivational copy. This is
// the part that must never read like marketing.
export function Note({ children, variant = 'warning' }) {
  const icon = variant === 'critical' ? '⚠️' : variant === 'info' ? 'ℹ️' : '💡';
  return (
    <div className={`note ${variant === 'critical' ? 'note--critical' : ''} ${variant === 'info' ? 'note--info' : ''}`}>
      <span className="note__icon" aria-hidden="true">{icon}</span>
      <div>{children}</div>
    </div>
  );
}

export function Empty({ icon = '📭', title, message, action }) {
  return (
    <div className="empty">
      <span className="empty__icon" aria-hidden="true">{icon}</span>
      <h3>{title}</h3>
      <p className="muted">{message}</p>
      {action}
    </div>
  );
}

export function Bar({ value, tint }) {
  const pct = Math.max(0, Math.min(1, value || 0)) * 100;
  return (
    <div className="bar">
      <div className="bar__fill" style={{ width: `${pct}%`, background: tint }} />
    </div>
  );
}

export function Ring({ value, label, caption, size = 120, tint = 'var(--accent)' }) {
  const stroke = 12;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const clamped = Math.max(0, Math.min(1, value || 0));

  return (
    <div className="ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} aria-hidden="true">
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--surface-3)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={tint}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference * (1 - clamped)}
        />
      </svg>
      <span className="ring__label">
        <span className="ring__value">{label}</span>
        <span className="ring__caption">{caption}</span>
      </span>
      <span className="visually-hidden">{`${label} ${caption}, ${Math.round(clamped * 100)} percent`}</span>
    </div>
  );
}

// Plus/minus rather than a slider: far easier to hit accurately with tremor or
// reduced fine motor control, and it announces its value properly.
export function Stepper({ value, min, max, step, format, onChange, label }) {
  return (
    <div
      className="stepper"
      role="group"
      aria-label={label}
    >
      <button
        type="button"
        className="stepper__btn"
        onClick={() => onChange(Math.max(min, value - step))}
        disabled={value <= min}
        aria-label={`Decrease ${label}`}
      >
        −
      </button>
      <output className="stepper__value">{format(value)}</output>
      <button
        type="button"
        className="stepper__btn"
        onClick={() => onChange(Math.min(max, value + step))}
        disabled={value >= max}
        aria-label={`Increase ${label}`}
      >
        +
      </button>
    </div>
  );
}

export function Option({ title, detail, selected, onClick, multi = false }) {
  return (
    <button type="button" className="option" aria-pressed={selected} onClick={onClick}>
      <span className="option__mark" aria-hidden="true">
        {multi ? (selected ? '☑' : '☐') : selected ? '◉' : '○'}
      </span>
      <span className="option__body">
        <span className="option__title">{title}</span>
        {detail && <span className="muted">{detail}</span>}
      </span>
    </button>
  );
}

export function Chip({ children, pressed, onClick }) {
  return (
    <button type="button" className="chip" aria-pressed={Boolean(pressed)} onClick={onClick}>
      {children}
    </button>
  );
}

// Every question in this app can show why it is being asked. People answer
// honestly about pain and falls when they can see what the answer is for, and
// evasively when it looks like data collection.
export function Question({ question, why, children }) {
  const [open, setOpen] = useState(false);
  const id = useId();

  return (
    <div className="stack">
      <h3 id={`${id}-label`}>{question}</h3>
      {why && (
        <>
          <button
            type="button"
            className="btn btn--ghost btn--small"
            style={{ alignSelf: 'flex-start', padding: 0, minHeight: 32 }}
            aria-expanded={open}
            aria-controls={`${id}-why`}
            onClick={() => setOpen((v) => !v)}
          >
            {open ? '▾ Hide' : '▸ Why we ask'}
          </button>
          {open && (
            <p id={`${id}-why`} className="muted">
              {why}
            </p>
          )}
        </>
      )}
      <div role="group" aria-labelledby={`${id}-label`} className="stack">
        {children}
      </div>
    </div>
  );
}

export function Modal({ title, onClose, children, footer }) {
  const ref = useRef(null);

  // Escape closes, and focus moves into the sheet so keyboard and screen-reader
  // users are not left behind on the page underneath.
  useEffect(() => {
    const onKey = (event) => {
      if (event.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    ref.current?.focus();

    const { overflow } = document.body.style;
    document.body.style.overflow = 'hidden';

    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = overflow;
    };
  }, [onClose]);

  return (
    <div className="modal-backdrop" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={title} tabIndex={-1} ref={ref}>
        <div className="modal__head">
          <h2>{title}</h2>
          <button type="button" className="btn btn--ghost btn--small" onClick={onClose}>
            Close
          </button>
        </div>
        {children}
        {footer}
      </div>
    </div>
  );
}

export function Toggle({ label, detail, checked, onChange }) {
  return (
    <label className="row row--between" style={{ minHeight: 'var(--tap)', gap: '1rem' }}>
      <span className="option__body">
        <span>{label}</span>
        {detail && <span className="tiny">{detail}</span>}
      </span>
      <input
        type="checkbox"
        checked={Boolean(checked)}
        onChange={(e) => onChange(e.target.checked)}
        style={{ width: 28, height: 28, flexShrink: 0, accentColor: 'var(--accent)' }}
      />
    </label>
  );
}
