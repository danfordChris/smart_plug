// dashboard-widgets.jsx — Hero card, Quick Access tiles, Insight cards, Bottom nav

const { useMemo: useMemoD } = React;

// ────────────────────────────────────────────────────────────────────────────
// Energy Hero Card — today's kWh + cost + sparkline
// ────────────────────────────────────────────────────────────────────────────
function EnergyHero({ kwh, deltaKwh, cost, costCurrency = '£', deltaCost, history, onReport }) {
  const w = 200, h = 48;
  const max = Math.max(...history, 0.001);
  const min = Math.min(...history);
  const range = (max - min) || 1;
  const points = history.map((v, i) => {
    const x = (i / (history.length - 1)) * w;
    const y = 6 + (1 - (v - min) / range) * (h - 12);
    return [x, y];
  });
  const path = points.reduce((acc, [x, y], i, arr) => {
    if (i === 0) return `M ${x.toFixed(1)} ${y.toFixed(1)}`;
    const [px, py] = arr[i - 1];
    const cx = px + (x - px) / 2;
    return `${acc} C ${cx.toFixed(1)} ${py.toFixed(1)} ${cx.toFixed(1)} ${y.toFixed(1)} ${x.toFixed(1)} ${y.toFixed(1)}`;
  }, '');
  const fillPath = `${path} L ${w} ${h} L 0 ${h} Z`;
  const gradId = useMemoD(() => 'hg-' + Math.random().toString(36).slice(2, 8), []);

  const Delta = ({ value, unit }) => {
    if (value == null) return null;
    const down = value < 0;
    return (
      <span className="hero-card-delta">
        <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
          <path d={down ? 'M2 3l3 4 3-4' : 'M2 7l3-4 3 4'} stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
        <span>{Math.abs(value)}{unit}</span>
      </span>
    );
  };

  return (
    <div className="hero-card">
      <div className="hero-card-grid">
        {/* Left: kWh */}
        <div>
          <div className="hero-card-label">Today's energy</div>
          <div className="hero-card-value">
            {kwh.toFixed(1)}
            <span className="hero-card-value-unit">kWh</span>
            <Delta value={deltaKwh} unit="%" />
          </div>
          <div className="hero-card-sub">vs yesterday</div>

          {/* sparkline */}
          <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" width="100%" height="44" style={{ display: 'block', marginTop: 8 }}>
            <defs>
              <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="currentColor" stopOpacity="0.35" />
                <stop offset="100%" stopColor="currentColor" stopOpacity="0" />
              </linearGradient>
            </defs>
            <path d={fillPath} fill={`url(#${gradId})`} />
            <path d={path} stroke="currentColor" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <div style={{
            display: 'flex', justifyContent: 'space-between',
            marginTop: 2, fontSize: 9,
            fontFamily: 'var(--font-mono)',
            opacity: 0.6,
          }}>
            <span>12 AM</span><span>6 AM</span><span>12 PM</span><span>6 PM</span><span>12 AM</span>
          </div>
        </div>

        <div className="hero-card-divider" />

        {/* Right: cost */}
        <div>
          <div className="hero-card-label">Estimated cost</div>
          <div className="hero-card-value">
            <span style={{ fontSize: 22, opacity: 0.85, marginRight: 1 }}>{costCurrency}</span>
            {cost.toFixed(2)}
            <Delta value={deltaCost} unit="%" />
          </div>
          <div className="hero-card-sub">vs yesterday</div>
          <button className="hero-card-report" onClick={onReport}>
            <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
              <rect x="2" y="9" width="2.5" height="5" rx="0.5" fill="currentColor" />
              <rect x="6.75" y="6" width="2.5" height="8" rx="0.5" fill="currentColor" />
              <rect x="11.5" y="3" width="2.5" height="11" rx="0.5" fill="currentColor" />
            </svg>
            View report
          </button>
        </div>
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Quick Access tile
// ────────────────────────────────────────────────────────────────────────────
function QuickTile({ icon, label, color = 'var(--m3-primary)', onClick }) {
  return (
    <button className="qa-tile" onClick={onClick} style={{ color }}>
      <div className="qa-tile-ico">{icon}</div>
      <span className="qa-tile-label">{label}</span>
    </button>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Insight card
// ────────────────────────────────────────────────────────────────────────────
function InsightCard({ icon, tint, title, desc, action, actionColor, onClick }) {
  return (
    <div className="insight-card" onClick={onClick} role="button" tabIndex={0}>
      <div className="insight-icon" style={{
        background: `color-mix(in oklab, ${tint} 18%, transparent)`,
        color: tint,
      }}>
        {icon}
      </div>
      <div className="insight-body">
        <h3 className="insight-title">{title}</h3>
        <p className="insight-desc">{desc}</p>
      </div>
      {action && (
        <div className="insight-action" style={{ color: actionColor || tint }}>
          <span>{action}</span>
          <IconChevronRight size={14} strokeWidth={2.4} />
        </div>
      )}
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Bottom Navigation Bar
// ────────────────────────────────────────────────────────────────────────────
function BottomNav({ active, onChange, onAdd }) {
  const tabs = [
    { id: 'home',     label: 'Home',       icon: <IconHome /> },
    { id: 'devices',  label: 'Devices',    icon: <IconDevices /> },
    { id: 'add',      label: '',           icon: <IconPlus size={22} strokeWidth={2.4} />, isFab: true },
    { id: 'insights', label: 'Insights',   icon: <IconChart /> },
    { id: 'profile',  label: 'Settings',   icon: <IconProfile /> },
  ];
  return (
    <nav className="bottom-nav">
      {tabs.map(tab => (
        tab.isFab ? (
          <div key={tab.id} style={{ flex: 1, display: 'flex', justifyContent: 'center', alignItems: 'flex-start' }}>
            <button className="bn-fab" onClick={onAdd} aria-label="Add device">
              {tab.icon}
            </button>
          </div>
        ) : (
          <button
            key={tab.id}
            className="bn-tab"
            data-active={active === tab.id}
            onClick={() => onChange(tab.id)}
          >
            <span className="bn-ico-wrap">{tab.icon}</span>
            <span className="bn-label">{tab.label}</span>
          </button>
        )
      ))}
    </nav>
  );
}

// Bottom-nav icons — Material-style filled outline
const IconHome = (p) => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <path d="M3 11l9-7 9 7v9a2 2 0 0 1-2 2h-3v-7H8v7H5a2 2 0 0 1-2-2v-9z" />
  </svg>
);
const IconDevices = (p) => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <rect x="3" y="4" width="8" height="16" rx="1.5" />
    <rect x="13" y="9" width="8" height="11" rx="1.5" />
    <path d="M7 17h.01M17 16h.01" />
  </svg>
);
const IconChart = (p) => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <path d="M3 3v18h18" />
    <path d="M7 14l4-4 3 3 5-6" />
  </svg>
);
const IconProfile = (p) => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <circle cx="12" cy="8" r="4" />
    <path d="M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1" />
  </svg>
);
const IconBell = (p) => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <path d="M6 8a6 6 0 0 1 12 0v5l1.5 3h-15L6 13V8z" />
    <path d="M10 19a2 2 0 0 0 4 0" />
  </svg>
);
const IconSchedule = (p) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <rect x="3" y="5" width="18" height="16" rx="2" />
    <path d="M3 9h18M8 3v4M16 3v4" />
    <circle cx="12" cy="15" r="2.4" />
    <path d="M12 14v1.5l1 1" />
  </svg>
);
const IconLeaf = (p) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <path d="M4 20c0-9 7-16 16-16 0 9-7 16-16 16z" />
    <path d="M4 20c4-4 7-7 11-11" />
  </svg>
);
const IconWarn = (p) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <path d="M12 3l10 18H2L12 3z" />
    <path d="M12 10v4M12 18h.01" />
  </svg>
);
const IconWrench = (p) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...p}>
    <path d="M14.7 6.3a4 4 0 0 0-5.4 5.4l-6 6 2.8 2.8 6-6a4 4 0 0 0 5.4-5.4l-2.4 2.4-2.8-2.8 2.4-2.4z" />
  </svg>
);

Object.assign(window, {
  EnergyHero, QuickTile, InsightCard, BottomNav,
  IconHome, IconDevices, IconChart, IconProfile, IconBell,
  IconSchedule, IconLeaf, IconWarn, IconWrench,
});
