// extras.jsx — Snackbar system, error states, EmptyState, more screens
// (Schedule, Maintain, Alerts, Optimize, Notifications, AddDevice flow)

const { useState: useStateE, useEffect: useEffectE, useContext: useContextE, useCallback: useCallbackE, useRef: useRefE, useMemo: useMemoE, createContext: createContextE } = React;

// ────────────────────────────────────────────────────────────────────────────
// Snackbar context
// ────────────────────────────────────────────────────────────────────────────
const SnackbarContext = createContextE(null);

function useSnackbar() {
  return useContextE(SnackbarContext);
}

function SnackbarProvider({ children }) {
  const [items, setItems] = useStateE([]);
  const idRef = useRefE(0);

  const dismiss = useCallbackE((id) => {
    setItems(prev => prev.filter(s => s.id !== id));
  }, []);

  const show = useCallbackE((opts) => {
    const id = ++idRef.current;
    const item = {
      id,
      text: typeof opts === 'string' ? opts : opts.text,
      kind: opts.kind || 'info',
      actionLabel: opts.actionLabel,
      onAction: opts.onAction,
      duration: opts.duration || 4000,
    };
    setItems(prev => [...prev.slice(-2), item]);
    if (item.duration > 0) {
      setTimeout(() => dismiss(id), item.duration);
    }
    return id;
  }, [dismiss]);

  return (
    <SnackbarContext.Provider value={{ show, dismiss }}>
      {children}
      <div className="snackbar-host">
        {items.map(s => (
          <div key={s.id} className={`snackbar ${s.kind === 'error' ? 'snackbar-error' : ''}`}>
            <span className="snackbar-text">{s.text}</span>
            {s.actionLabel && (
              <button
                className="snackbar-action"
                onClick={() => { s.onAction && s.onAction(); dismiss(s.id); }}
              >{s.actionLabel}</button>
            )}
            <button className="snackbar-close" onClick={() => dismiss(s.id)} aria-label="Dismiss">
              <IconClose size={16} strokeWidth={2.2} />
            </button>
          </div>
        ))}
      </div>
    </SnackbarContext.Provider>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// EmptyState
// ────────────────────────────────────────────────────────────────────────────
function EmptyState({ icon, title, desc, action }) {
  return (
    <div className="empty">
      <div className="empty-icon">{icon}</div>
      <h3>{title}</h3>
      <p>{desc}</p>
      {action}
    </div>
  );
}

// Re-usable secondary AppBar (back arrow only)
function BackAppBar({ title, onBack, trailing }) {
  return (
    <AppBar
      leading={<button className="appbar-icon" onClick={onBack} aria-label="Back"><IconArrowBack /></button>}
      title={title}
      trailing={trailing}
    />
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Schedule screen
// ────────────────────────────────────────────────────────────────────────────
function ScheduleScreen({ onBack, plugs, snack }) {
  const [items, setItems] = useStateE([
    { id: 1, name: 'Off-peak fridge cooldown', cron: 'Daily · 00:30 – 04:30', target: 'switch.fridge', action: 'On', enabled: true },
    { id: 2, name: 'Morning radio',             cron: 'Weekdays · 07:00',     target: 'switch.radio',  action: 'On',  enabled: true },
    { id: 3, name: 'Radio off at bedtime',      cron: 'Daily · 23:00',         target: 'switch.radio',  action: 'Off', enabled: false },
  ]);

  const toggle = (id) => {
    setItems(prev => prev.map(i => i.id === id ? { ...i, enabled: !i.enabled } : i));
    const item = items.find(i => i.id === id);
    snack.show(`Schedule "${item.name}" ${item.enabled ? 'paused' : 'resumed'}`);
  };

  return (
    <>
      <BackAppBar
        title="Schedules"
        onBack={onBack}
        trailing={
          <button className="appbar-icon" aria-label="Add schedule"
            onClick={() => snack.show('Coming soon: create a new schedule', { duration: 2500 })}>
            <IconPlus />
          </button>
        }
      />
      <div className="scroll" style={{ padding: '0 16px 24px' }}>
        <div style={{ padding: '0 4px 12px', fontSize: 13, color: 'var(--m3-on-surface-variant)' }}>
          Automations run on Home Assistant. Toggle to pause.
        </div>

        {items.length === 0 ? (
          <EmptyState
            icon={<IconSchedule />}
            title="No schedules yet"
            desc="Create automations in Home Assistant or tap + above to set one up."
          />
        ) : (
          <div className="list-card">
            {items.map(item => (
              <div key={item.id} className="list-row">
                <div className="list-row-ico" style={{
                  background: item.enabled ? 'var(--m3-primary-container)' : 'var(--m3-surface-container-high)',
                  color: item.enabled ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                }}>
                  <IconSchedule />
                </div>
                <div className="list-row-body">
                  <div className="list-row-title">{item.name}</div>
                  <div className="list-row-sub">
                    {item.cron} · <span style={{ fontFamily: 'var(--font-mono)' }}>{item.target}</span>
                    <span style={{ marginLeft: 6 }} className={`chip ${item.action === 'On' ? 'chip-ok' : 'chip-info'}`}>
                      {item.action}
                    </span>
                  </div>
                </div>
                <M3Switch on={item.enabled} onChange={() => toggle(item.id)} />
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Maintain screen
// ────────────────────────────────────────────────────────────────────────────
function MaintainScreen({ onBack, plugs }) {
  const tasks = [
    { id: 1, icon: <IconWrench />, tint: 'oklch(0.6 0.16 30)', title: 'Fridge compressor service', desc: 'Cycle drift detected — book service within 30 days.', chip: 'High', chipKind: 'chip-error' },
    { id: 2, icon: <IconBolt size={18} strokeWidth={2} />, tint: 'oklch(0.6 0.16 60)', title: 'Replace radio plug filter', desc: 'Last serviced 6 months ago.', chip: 'Medium', chipKind: 'chip-warn' },
    { id: 3, icon: <IconCheck size={20} strokeWidth={2.4} />, tint: 'var(--m3-success)', title: 'Firmware up to date', desc: 'Last checked 2 days ago. All plugs on v3.4.1.', chip: 'OK', chipKind: 'chip-ok' },
  ];
  return (
    <>
      <BackAppBar title="Maintenance" onBack={onBack} />
      <div className="scroll" style={{ padding: '0 16px 24px' }}>
        {/* Summary */}
        <div className="card" style={{ cursor: 'default', marginBottom: 16 }}>
          <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase', color: 'var(--m3-on-surface-variant)' }}>
            Devices healthy
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 4 }}>
            <span className="num" style={{ fontSize: 36, color: 'var(--m3-on-surface)' }}>2</span>
            <span style={{ fontSize: 14, color: 'var(--m3-on-surface-variant)' }}>of 2 reachable</span>
          </div>
          <div style={{ fontSize: 12, color: 'var(--m3-on-surface-variant)', marginTop: 4 }}>
            1 maintenance task needs attention
          </div>
        </div>

        <div className="section-head"><h2>Tasks</h2></div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {tasks.map(t => (
            <div key={t.id} className="insight-card">
              <div className="insight-icon" style={{
                background: `color-mix(in oklab, ${t.tint} 18%, transparent)`,
                color: t.tint,
              }}>{t.icon}</div>
              <div className="insight-body">
                <h3 className="insight-title">{t.title}</h3>
                <p className="insight-desc">{t.desc}</p>
              </div>
              <span className={`chip ${t.chipKind}`}>{t.chip}</span>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Alerts screen
// ────────────────────────────────────────────────────────────────────────────
function AlertsScreen({ onBack, alerts, onClearAll, snack }) {
  return (
    <>
      <BackAppBar
        title="Alerts"
        onBack={onBack}
        trailing={alerts.length > 0 ? (
          <button
            className="appbar-icon"
            aria-label="Mark all read"
            onClick={() => { onClearAll(); snack.show('Marked all alerts read'); }}
          >
            <IconCheck />
          </button>
        ) : null}
      />
      <div className="scroll" style={{ padding: '0 16px 24px' }}>
        {alerts.length === 0 ? (
          <EmptyState
            icon={<IconCheck size={32} strokeWidth={2} />}
            title="All clear"
            desc="No active alerts. We'll notify you when something needs attention."
          />
        ) : (
          <div className="list-card">
            {alerts.map(a => (
              <div key={a.id} className="list-row">
                <div className="list-row-ico" style={{
                  background: `color-mix(in oklab, ${a.tint} 18%, transparent)`,
                  color: a.tint,
                }}>
                  {a.icon}
                </div>
                <div className="list-row-body">
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                    {a.unread && <span style={{ width: 6, height: 6, borderRadius: 3, background: 'var(--m3-primary)', flexShrink: 0 }} />}
                    <span className="list-row-title">{a.title}</span>
                  </div>
                  <div className="list-row-sub">{a.desc}</div>
                </div>
                <span className="list-row-meta">{a.time}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Optimize screen
// ────────────────────────────────────────────────────────────────────────────
function OptimizeScreen({ onBack }) {
  const tips = [
    { id: 1, save: '£4.50/mo', icon: <IconLeaf />, title: 'Use off-peak window', desc: 'Shift fridge cooling and heavy loads to 00:30–04:30 to use cheaper tariff.' },
    { id: 2, save: '£1.20/mo', icon: <IconBolt size={18} strokeWidth={2} />, title: 'Reduce standby draw', desc: 'Radio is drawing 7.8 W when idle. Schedule auto-off after 1 h of no activity.' },
    { id: 3, save: '£0.80/mo', icon: <IconSchedule />, title: 'Cycle fridge during sleep', desc: 'Run compressor on a 22-min cycle overnight when ambient is cooler.' },
  ];
  const totalSave = '£6.50';
  return (
    <>
      <BackAppBar title="Optimize" onBack={onBack} />
      <div className="scroll" style={{ padding: '0 16px 24px' }}>
        <div className="hero-card" style={{ marginBottom: 16 }}>
          <div className="hero-card-label">Potential savings</div>
          <div className="hero-card-value">
            {totalSave}<span className="hero-card-value-unit">/month</span>
          </div>
          <div className="hero-card-sub">If you adopt all 3 recommendations below.</div>
        </div>

        <div className="section-head"><h2>Recommendations</h2></div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {tips.map(t => (
            <div key={t.id} className="insight-card">
              <div className="insight-icon" style={{
                background: 'color-mix(in oklab, var(--m3-primary) 18%, transparent)',
                color: 'var(--m3-primary)',
              }}>{t.icon}</div>
              <div className="insight-body">
                <h3 className="insight-title">{t.title}</h3>
                <p className="insight-desc">{t.desc}</p>
              </div>
              <span className="chip chip-ok">{t.save}</span>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Notifications screen
// ────────────────────────────────────────────────────────────────────────────
function NotificationsScreen({ onBack, alerts, onClearAll, snack }) {
  return <AlertsScreen onBack={onBack} alerts={alerts} onClearAll={onClearAll} snack={snack} />;
}

// ────────────────────────────────────────────────────────────────────────────
// Add Device — full screen flow (not modal)
// ────────────────────────────────────────────────────────────────────────────
function AddDeviceScreen({ onBack, snack }) {
  const [step, setStep] = useStateE(0);
  const [scanning, setScanning] = useStateE(false);
  const [found, setFound] = useStateE([]);
  const totalSteps = 3;

  const startScan = () => {
    setScanning(true);
    setFound([]);
    setTimeout(() => {
      setFound([{ id: 'kettle', name: 'SonOFF S60TPG (192.168.1.42)', mac: 'EC:FA:BC:12:34:56' }]);
      setScanning(false);
    }, 2400);
  };

  return (
    <>
      <BackAppBar title="Add device" onBack={onBack} />

      {/* Progress */}
      <div style={{ padding: '0 16px 16px' }}>
        <div style={{ display: 'flex', gap: 6 }}>
          {Array.from({ length: totalSteps }).map((_, i) => (
            <div key={i} style={{
              flex: 1, height: 4, borderRadius: 2,
              background: i <= step ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
              transition: 'background 240ms ease',
            }} />
          ))}
        </div>
        <div style={{ marginTop: 8, fontSize: 11, fontFamily: 'var(--font-mono)', color: 'var(--m3-on-surface-variant)' }}>
          Step {step + 1} of {totalSteps}
        </div>
      </div>

      <div className="scroll" style={{ padding: '0 24px 24px' }}>
        {step === 0 && (
          <>
            <h1 style={{ margin: '8px 0 4px', fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600, letterSpacing: '-0.02em', color: 'var(--m3-on-surface)' }}>
              Put the plug into pairing mode
            </h1>
            <p style={{ margin: 0, fontSize: 14, lineHeight: 1.55, color: 'var(--m3-on-surface-variant)' }}>
              Press and hold the button on the SonOFF S60TPG plug for 5 seconds until the LED blinks blue.
            </p>
            <div style={{
              marginTop: 24, padding: 24,
              background: 'var(--m3-surface-container-low)',
              borderRadius: 16,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <PlugDiagram />
            </div>
          </>
        )}
        {step === 1 && (
          <>
            <h1 style={{ margin: '8px 0 4px', fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600, letterSpacing: '-0.02em', color: 'var(--m3-on-surface)' }}>
              Scan your network
            </h1>
            <p style={{ margin: 0, fontSize: 14, lineHeight: 1.55, color: 'var(--m3-on-surface-variant)' }}>
              We'll look for new SonOFF plugs on your local network. Make sure your phone is on the same Wi-Fi.
            </p>
            <div style={{
              marginTop: 20, padding: 20,
              background: 'var(--m3-surface-container-low)',
              borderRadius: 16,
              minHeight: 160,
              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12,
            }}>
              {scanning && <Spinner />}
              {!scanning && found.length === 0 && (
                <>
                  <IconWifi />
                  <div style={{ fontSize: 13, color: 'var(--m3-on-surface-variant)' }}>Ready to scan</div>
                  <button className="btn btn-tonal" onClick={startScan}>Start scan</button>
                </>
              )}
              {!scanning && found.length > 0 && (
                <div style={{ width: '100%' }}>
                  <div style={{ fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em', color: 'var(--m3-success)', marginBottom: 8 }}>
                    Found {found.length}
                  </div>
                  {found.map(d => (
                    <div key={d.id} className="list-row" style={{ padding: '12px 0' }}>
                      <div className="list-row-ico" style={{ background: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}>
                        <IconBolt size={20} strokeWidth={2} />
                      </div>
                      <div className="list-row-body">
                        <div className="list-row-title">{d.name}</div>
                        <div className="list-row-sub" style={{ fontFamily: 'var(--font-mono)' }}>{d.mac}</div>
                      </div>
                      <span className="chip chip-ok">New</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}
        {step === 2 && (
          <>
            <h1 style={{ margin: '8px 0 4px', fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600, letterSpacing: '-0.02em', color: 'var(--m3-on-surface)' }}>
              Name your plug
            </h1>
            <p style={{ margin: 0, fontSize: 14, lineHeight: 1.55, color: 'var(--m3-on-surface-variant)' }}>
              Pick a friendly name that matches the appliance you've plugged in.
            </p>
            <div style={{ marginTop: 20 }}>
              <TextField label="Device name" value="Kettle" onChange={() => {}} />
              <TextField label="Room" value="Kitchen" onChange={() => {}} />
            </div>
            <div style={{
              marginTop: 16, padding: 14,
              background: 'color-mix(in oklab, var(--m3-success) 12%, transparent)',
              borderRadius: 12,
              border: '1px solid color-mix(in oklab, var(--m3-success) 25%, transparent)',
              display: 'flex', gap: 10, alignItems: 'flex-start',
            }}>
              <div style={{ color: 'var(--m3-success)', flexShrink: 0, marginTop: 1 }}>
                <IconCheck size={18} strokeWidth={2.5} />
              </div>
              <div>
                <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--m3-on-surface)' }}>Ready to add</div>
                <div style={{ fontSize: 12, color: 'var(--m3-on-surface-variant)', marginTop: 2 }}>
                  This will create switch.kettle, sensor.kettle_power, and 3 more entities in Home Assistant.
                </div>
              </div>
            </div>
          </>
        )}
      </div>

      {/* Bottom action bar */}
      <div style={{
        padding: '12px 16px 16px',
        borderTop: '1px solid var(--m3-outline-variant)',
        background: 'var(--m3-surface)',
        display: 'flex', gap: 10,
      }}>
        {step > 0 && (
          <button className="btn btn-tonal" style={{ flex: 1, height: 48, borderRadius: 24 }} onClick={() => setStep(s => s - 1)}>
            Back
          </button>
        )}
        <button
          className="btn btn-filled"
          style={{ flex: step > 0 ? 1 : undefined, width: step > 0 ? undefined : '100%', height: 48, borderRadius: 24 }}
          disabled={step === 1 && found.length === 0}
          onClick={() => {
            if (step < totalSteps - 1) {
              setStep(s => s + 1);
            } else {
              snack.show('Kettle added · 5 entities created in Home Assistant');
              onBack();
            }
          }}
        >
          {step === totalSteps - 1 ? 'Add device' : 'Continue'}
        </button>
      </div>
    </>
  );
}

// Simple SVG illustration of the plug for the pairing step
function PlugDiagram() {
  return (
    <svg width="160" height="160" viewBox="0 0 160 160" fill="none">
      {/* outer plug body */}
      <rect x="30" y="30" width="100" height="100" rx="20"
        fill="var(--m3-surface-container)" stroke="var(--m3-outline-variant)" strokeWidth="1.5" />
      {/* power button */}
      <circle cx="80" cy="80" r="22" fill="var(--m3-surface)" stroke="var(--m3-primary)" strokeWidth="2" />
      <path d="M80 70 V82" stroke="var(--m3-primary)" strokeWidth="2.5" strokeLinecap="round" />
      <path d="M68 80 a12 12 0 1 0 24 0" stroke="var(--m3-primary)" strokeWidth="2.5" strokeLinecap="round" fill="none" strokeDasharray="4 2" />
      {/* LED — pulse */}
      <circle cx="80" cy="118" r="3" fill="var(--m3-primary)">
        <animate attributeName="opacity" values="1;0.3;1" dur="1.4s" repeatCount="indefinite" />
      </circle>
      {/* prongs */}
      <rect x="60" y="20" width="8" height="14" rx="2" fill="var(--m3-outline)" />
      <rect x="92" y="20" width="8" height="14" rx="2" fill="var(--m3-outline)" />
    </svg>
  );
}

Object.assign(window, {
  SnackbarProvider, useSnackbar, EmptyState, BackAppBar,
  ScheduleScreen, MaintainScreen, AlertsScreen, OptimizeScreen,
  NotificationsScreen, AddDeviceScreen,
});
