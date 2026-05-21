// widgets.jsx — Reusable M3 widgets for the Smart Plugs app
// PlugCard, StatTile, M3Switch, ConnectionBanner, Sparkline, TextField, AppBar

const { useState, useEffect, useRef, useMemo } = React;

// ─── M3 Switch ──────────────────────────────────────────────────────────────
function M3Switch({ on, onChange, disabled = false, size = 'normal', tone }) {
  return (
    <button
      type="button"
      className={`m3-switch ${size === 'big' ? 'm3-switch-big' : ''} tap`}
      data-on={!!on}
      data-disabled={!!disabled}
      data-tone={tone || undefined}
      onClick={(e) => { e.stopPropagation(); if (!disabled) onChange(!on); }}
      aria-pressed={!!on}
      aria-disabled={disabled}
      style={{ padding: 0 }}
    >
      <span className="m3-switch-thumb">
        {on && size === 'big' && <IconCheck size={18} strokeWidth={2.5} />}
        {on && size !== 'big' && <IconCheck size={14} strokeWidth={3} />}
      </span>
    </button>
  );
}

// ─── M3 Outlined Text Field ─────────────────────────────────────────────────
function TextField({ label, value, onChange, type = 'text', helper, trailing, autoFocus }) {
  const id = useMemo(() => 'tf-' + Math.random().toString(36).slice(2, 8), []);
  const filled = value && value.length > 0;
  return (
    <div className="tf">
      <input
        id={id}
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={`tf-input ${filled ? 'tf-filled' : ''}`}
        placeholder=" "
        autoFocus={autoFocus}
        autoComplete="off"
        spellCheck="false"
        style={{ paddingRight: trailing ? 48 : undefined }}
      />
      <label htmlFor={id} className="tf-label">{label}</label>
      {trailing}
      {helper && <div className="tf-helper">{helper}</div>}
    </div>
  );
}

// ─── App Bar ────────────────────────────────────────────────────────────────
function AppBar({ leading, title, trailing }) {
  return (
    <div className="appbar">
      {leading || <div style={{ width: 12 }} />}
      <div className="appbar-title">{title}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 0, paddingRight: 4 }}>
        {trailing}
      </div>
    </div>
  );
}

// ─── Connection Banner ──────────────────────────────────────────────────────
function ConnectionBanner({ onRetry }) {
  return (
    <div className="banner">
      <IconCloudOff />
      <span>Disconnected — couldn't reach Home Assistant</span>
      <button className="banner-action" onClick={onRetry}>Retry</button>
    </div>
  );
}

// ─── Plug Card ──────────────────────────────────────────────────────────────
function PlugCard({ plug, onToggle, onOpen }) {
  const isOn = plug.state === 'on';
  const unavailable = plug.state === 'unavailable';
  const Glyph = plug.id === 'radio' ? IconRadio : IconFridge;

  return (
    <div className="card tap" onClick={onOpen} role="button" tabIndex={0}>
      {/* Top row: glyph + name + switch */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{
          width: 56, height: 56, borderRadius: 16,
          background: isOn ? 'var(--m3-primary-container)' : 'var(--m3-surface-container-high)',
          color: isOn ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          flexShrink: 0,
          transition: 'background 200ms ease, color 200ms ease',
        }}>
          <Glyph size={30} />
        </div>

        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{
              fontFamily: 'var(--font-display)',
              fontSize: 20, fontWeight: 600,
              color: 'var(--m3-on-surface)',
              letterSpacing: '-0.01em',
            }}>{plug.name}</span>
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            fontSize: 12, color: 'var(--m3-on-surface-variant)',
            marginTop: 2,
            fontVariantNumeric: 'tabular-nums',
          }}>
            <span className="dot" data-state={unavailable ? 'unavailable' : (isOn ? 'on' : 'off')} />
            <span>
              {unavailable ? 'Unavailable'
                : isOn ? `On · ${plug.entity_id}`
                : `Off · ${plug.entity_id}`}
            </span>
          </div>
        </div>

        <M3Switch on={isOn} disabled={unavailable} onChange={() => onToggle(plug.id)} />
      </div>

      {/* Power readout */}
      <div style={{
        marginTop: 14,
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12,
      }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span className="num" style={{
            fontSize: 44,
            color: unavailable ? 'var(--m3-outline)' : (isOn ? 'var(--m3-on-surface)' : 'var(--m3-outline)'),
            transition: 'color 200ms ease',
          }}>
            {unavailable ? '—' : plug.power.toFixed(1)}
          </span>
          <span style={{
            fontSize: 14, fontWeight: 500,
            color: 'var(--m3-on-surface-variant)',
          }}>W</span>
        </div>

        <MiniBars values={plug.history} active={isOn && !unavailable} />
      </div>
    </div>
  );
}

// ─── Tiny inline bar graph for the card ─────────────────────────────────────
function MiniBars({ values, active }) {
  const max = Math.max(...values, 1);
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-end', gap: 2,
      height: 28,
    }}>
      {values.slice(-16).map((v, i) => {
        const h = Math.max(2, (v / max) * 28);
        return (
          <div key={i} style={{
            width: 3, height: h,
            borderRadius: 1.5,
            background: active ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
            opacity: 0.4 + (i / 16) * 0.6,
            transition: 'height 320ms ease, background 200ms ease',
          }} />
        );
      })}
    </div>
  );
}

// ─── Skeleton card ──────────────────────────────────────────────────────────
function PlugCardSkeleton() {
  return (
    <div className="card" style={{ cursor: 'default' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        <div className="skel" style={{ width: 56, height: 56, borderRadius: 16 }} />
        <div style={{ flex: 1 }}>
          <div className="skel" style={{ width: '40%', height: 18, marginBottom: 8 }} />
          <div className="skel" style={{ width: '60%', height: 12 }} />
        </div>
        <div className="skel" style={{ width: 52, height: 32, borderRadius: 16 }} />
      </div>
      <div style={{ marginTop: 14, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <div className="skel" style={{ width: 80, height: 36 }} />
        <div className="skel" style={{ width: 60, height: 24 }} />
      </div>
    </div>
  );
}

// ─── Stat Tile (detail screen 2x2 grid) ─────────────────────────────────────
function StatTile({ label, value, unit, icon, accent = false }) {
  return (
    <div style={{
      background: accent ? 'var(--m3-primary-container)' : 'var(--m3-surface-container-low)',
      color: accent ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface)',
      borderRadius: 16,
      padding: '16px 16px 18px',
      display: 'flex', flexDirection: 'column', gap: 4,
      transition: 'background 240ms ease, color 240ms ease',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6,
        color: accent ? 'inherit' : 'var(--m3-on-surface-variant)',
        opacity: accent ? 0.85 : 1,
      }}>
        {icon}
        <span style={{ fontSize: 12, fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase' }}>
          {label}
        </span>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 4 }}>
        <span className="num" style={{ fontSize: 32 }}>{value}</span>
        <span style={{ fontSize: 14, fontWeight: 500, opacity: 0.7 }}>{unit}</span>
      </div>
    </div>
  );
}

// ─── Sparkline (detail) ─────────────────────────────────────────────────────
function Sparkline({ values, color, fillColor, active }) {
  const w = 320, h = 80;
  const padTop = 8, padBot = 4;
  const max = Math.max(...values, 1);
  const min = 0;
  const range = max - min || 1;

  const points = values.map((v, i) => {
    const x = (i / (values.length - 1)) * w;
    const y = padTop + (1 - (v - min) / range) * (h - padTop - padBot);
    return [x, y];
  });

  // Smooth path using cubic bezier
  const path = points.reduce((acc, [x, y], i, arr) => {
    if (i === 0) return `M ${x.toFixed(1)} ${y.toFixed(1)}`;
    const [px, py] = arr[i - 1];
    const cx1 = px + (x - px) / 2;
    const cy1 = py;
    const cx2 = px + (x - px) / 2;
    const cy2 = y;
    return `${acc} C ${cx1.toFixed(1)} ${cy1.toFixed(1)} ${cx2.toFixed(1)} ${cy2.toFixed(1)} ${x.toFixed(1)} ${y.toFixed(1)}`;
  }, '');

  const fillPath = `${path} L ${w} ${h - padBot} L 0 ${h - padBot} Z`;

  const last = points[points.length - 1];
  const lastVal = values[values.length - 1];

  const gradId = useMemo(() => 'spark-grad-' + Math.random().toString(36).slice(2, 8), []);

  return (
    <div className="spark-wrap">
      <div style={{
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        marginBottom: 8,
      }}>
        <div>
          <div style={{
            fontSize: 12, fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase',
            color: 'var(--m3-on-surface-variant)',
          }}>Power · last 60 min</div>
          <div style={{ marginTop: 2, display: 'flex', alignItems: 'baseline', gap: 4 }}>
            <span className="num" style={{ fontSize: 22, color: 'var(--m3-on-surface)' }}>{lastVal.toFixed(1)}</span>
            <span style={{ fontSize: 13, color: 'var(--m3-on-surface-variant)', fontWeight: 500 }}>W now</span>
          </div>
        </div>
        <div style={{ textAlign: 'right', fontSize: 11, color: 'var(--m3-on-surface-variant)', fontVariantNumeric: 'tabular-nums' }}>
          <div>peak {max.toFixed(1)} W</div>
          <div>avg {(values.reduce((a,b)=>a+b,0)/values.length).toFixed(1)} W</div>
        </div>
      </div>

      <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" width="100%" height="100" style={{ display: 'block' }}>
        <defs>
          <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={fillColor} stopOpacity={active ? 0.32 : 0.12} />
            <stop offset="100%" stopColor={fillColor} stopOpacity="0" />
          </linearGradient>
        </defs>
        {/* baseline */}
        <line x1="0" y1={h - padBot} x2={w} y2={h - padBot} stroke="var(--m3-outline-variant)" strokeWidth="0.5" />
        {/* fill */}
        <path d={fillPath} fill={`url(#${gradId})`} />
        {/* line */}
        <path d={path} stroke={color} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"
          style={{ opacity: active ? 1 : 0.5, transition: 'opacity 300ms ease' }} />
        {/* last point */}
        <circle cx={last[0]} cy={last[1]} r="3.5" fill="var(--m3-surface)" stroke={color} strokeWidth="2" />
      </svg>

      {/* Time axis labels */}
      <div style={{
        display: 'flex', justifyContent: 'space-between',
        marginTop: 4, fontSize: 10,
        fontFamily: 'var(--font-mono)',
        color: 'var(--m3-on-surface-variant)', opacity: 0.6,
      }}>
        <span>−60m</span><span>−45m</span><span>−30m</span><span>−15m</span><span>now</span>
      </div>
    </div>
  );
}

Object.assign(window, {
  M3Switch, TextField, AppBar, ConnectionBanner,
  PlugCard, PlugCardSkeleton, StatTile, Sparkline, MiniBars,
});
