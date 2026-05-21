// screens.jsx — Setup, Dashboard, Detail screens for the Smart Plugs app

const { useState: useStateS, useEffect: useEffectS, useRef: useRefS, useMemo: useMemoS } = React;

// ────────────────────────────────────────────────────────────────────────────
// Screen 1 — Setup / Connection
// ────────────────────────────────────────────────────────────────────────────
function SetupScreen({ initialUrl, initialToken, onSave, onCancel }) {
  const [url, setUrl] = useStateS(initialUrl || 'http://100.83.45.15:8123');
  const [token, setToken] = useStateS(initialToken || '');
  const [showToken, setShowToken] = useStateS(false);
  const [testing, setTesting] = useStateS(false);
  const [testResult, setTestResult] = useStateS(null); // 'ok' | 'fail' | null

  const canTest = url.trim().length > 8 && token.trim().length > 8;

  const runTest = () => {
    if (!canTest) return;
    setTesting(true);
    setTestResult(null);
    // Simulate network — 1.2s
    setTimeout(() => {
      setTesting(false);
      // Always succeed in the prototype unless token literally starts with 'bad'
      setTestResult(token.startsWith('bad') ? 'fail' : 'ok');
    }, 1200);
  };

  return (
    <>
      <AppBar
        leading={onCancel ? (
          <button className="appbar-icon" onClick={onCancel}><IconArrowBack /></button>
        ) : null}
        title="Setup"
      />

      <div className="scroll" style={{ padding: '8px 24px 24px' }}>
        {/* Hero header */}
        <div style={{ padding: '12px 0 28px' }}>
          <div style={{
            width: 64, height: 64, borderRadius: 20,
            background: 'var(--m3-primary-container)',
            color: 'var(--m3-on-primary-container)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            marginBottom: 16,
          }}>
            <IconBolt size={32} strokeWidth={1.8} />
          </div>
          <h1 style={{
            fontFamily: 'var(--font-display)',
            fontSize: 30, fontWeight: 600,
            letterSpacing: '-0.02em',
            margin: '0 0 6px',
            lineHeight: 1.15,
            color: 'var(--m3-on-surface)',
          }}>Connect your Home Assistant</h1>
          <p style={{
            margin: 0, fontSize: 14, lineHeight: 1.5,
            color: 'var(--m3-on-surface-variant)',
          }}>
            Paste your instance URL and a long-lived access token. The app talks
            directly to Home Assistant — no cloud in between.
          </p>
        </div>

        {/* URL field */}
        <div style={{ marginBottom: 8 }}>
          <TextField
            label="Home Assistant URL"
            value={url}
            onChange={setUrl}
            helper="Tailscale IP, LAN IP, or domain. Include http(s):// and port."
          />
        </div>

        {/* Token field */}
        <div style={{ marginBottom: 16 }}>
          <TextField
            label="Long-Lived Access Token"
            value={token}
            onChange={setToken}
            type={showToken ? 'text' : 'password'}
            helper="Profile → Security → Long-Lived Access Tokens → Create Token"
            trailing={
              <button
                type="button"
                className="tf-trailing"
                onClick={() => setShowToken(s => !s)}
                aria-label={showToken ? 'Hide token' : 'Show token'}
              >
                {showToken ? <IconEyeOff /> : <IconEye />}
              </button>
            }
          />
        </div>

        {/* Test connection */}
        <button
          className="btn btn-tonal"
          onClick={runTest}
          disabled={!canTest || testing}
          style={{ width: '100%', height: 48, borderRadius: 24, marginTop: 4 }}
        >
          {testing && <Spinner />}
          {!testing && testResult === 'ok' && <IconCheck size={18} strokeWidth={2.5} />}
          {!testing && testResult === 'fail' && <IconAlert size={18} />}
          {!testing && !testResult && <IconWifi size={18} />}
          <span>
            {testing ? 'Testing…'
              : testResult === 'ok' ? 'Connected'
              : testResult === 'fail' ? 'Couldn’t reach instance'
              : 'Test connection'}
          </span>
        </button>

        {testResult === 'ok' && (
          <div style={{
            marginTop: 16, padding: 14,
            background: 'color-mix(in oklab, var(--m3-success) 12%, transparent)',
            borderRadius: 12,
            display: 'flex', gap: 10, alignItems: 'flex-start',
            border: '1px solid color-mix(in oklab, var(--m3-success) 25%, transparent)',
          }}>
            <div style={{ color: 'var(--m3-success)', flexShrink: 0, marginTop: 1 }}>
              <IconCheck size={18} strokeWidth={2.5} />
            </div>
            <div>
              <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--m3-on-surface)' }}>Home Assistant 2025.5.1</div>
              <div style={{ fontSize: 12, color: 'var(--m3-on-surface-variant)', marginTop: 2 }}>
                Found 2 switch entities: switch.radio, switch.fridge
              </div>
            </div>
          </div>
        )}

        {testResult === 'fail' && (
          <div style={{
            marginTop: 16, padding: 14,
            background: 'var(--m3-error-container)',
            borderRadius: 12,
            display: 'flex', gap: 10, alignItems: 'flex-start',
          }}>
            <div style={{ color: 'var(--m3-error)', flexShrink: 0, marginTop: 1 }}>
              <IconAlert size={18} />
            </div>
            <div>
              <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--m3-error)' }}>Couldn’t connect</div>
              <div style={{ fontSize: 12, color: 'var(--m3-on-surface-variant)', marginTop: 2 }}>
                Check that the URL is reachable from this device and the token is valid.
              </div>
            </div>
          </div>
        )}

        {/* Token help — collapsible */}
        <TokenHelp />

        <div style={{ height: 24 }} />
      </div>

      {/* Bottom action bar */}
      <div style={{
        padding: '12px 24px 16px',
        borderTop: '1px solid var(--m3-outline-variant)',
        background: 'var(--m3-surface)',
        display: 'flex', gap: 12,
      }}>
        <button
          className="btn btn-filled"
          style={{ flex: 1, height: 48, borderRadius: 24, fontSize: 15 }}
          disabled={testResult !== 'ok'}
          onClick={() => onSave({ url, token })}
        >
          Save & Continue
        </button>
      </div>
    </>
  );
}

function TokenHelp() {
  const [open, setOpen] = useStateS(false);
  return (
    <div style={{
      marginTop: 24,
      borderRadius: 12,
      background: 'var(--m3-surface-container)',
      overflow: 'hidden',
    }}>
      <button
        onClick={() => setOpen(o => !o)}
        style={{
          width: '100%', textAlign: 'left',
          padding: 14, border: 0, background: 'transparent',
          color: 'var(--m3-on-surface)',
          display: 'flex', alignItems: 'center', gap: 10,
          cursor: 'pointer',
          fontFamily: 'var(--font-body)',
          fontSize: 14, fontWeight: 500,
        }}
      >
        <IconHelp size={20} />
        <span style={{ flex: 1 }}>How to generate a token</span>
        <span style={{ transform: open ? 'rotate(90deg)' : 'rotate(0)', transition: 'transform 200ms' }}>
          <IconChevronRight size={18} />
        </span>
      </button>
      {open && (
        <div style={{
          padding: '0 14px 14px',
          fontSize: 13, lineHeight: 1.55,
          color: 'var(--m3-on-surface-variant)',
        }}>
          <ol style={{ margin: 0, paddingLeft: 18 }}>
            <li>Open Home Assistant in your browser.</li>
            <li>Click your profile avatar (bottom-left).</li>
            <li>Switch to the <b>Security</b> tab.</li>
            <li>Scroll to <b>Long-Lived Access Tokens</b> → <b>Create Token</b>.</li>
            <li>Name it (e.g. “Phone”), copy the token <i>once</i>, paste it above.</li>
          </ol>
        </div>
      )}
    </div>
  );
}

function Spinner() {
  return (
    <span style={{
      display: 'inline-block', width: 18, height: 18,
      borderRadius: '50%',
      border: '2px solid currentColor', borderRightColor: 'transparent',
      animation: 'spin 0.7s linear infinite',
    }} />
  );
}

// inject keyframes for spinner (once)
if (!document.getElementById('__spin_kf')) {
  const s = document.createElement('style');
  s.id = '__spin_kf';
  s.textContent = '@keyframes spin{to{transform:rotate(360deg)}}';
  document.head.appendChild(s);
}

// ────────────────────────────────────────────────────────────────────────────
// Screen 2 — Dashboard
// ────────────────────────────────────────────────────────────────────────────
function DashboardScreen({ plugs, onToggle, onOpen, onSettings, onRefresh, refreshing, disconnected, loading, lastUpdated, energyToday, costToday, dayHistory, onShowReport, onQuickAccess, onAllInsights, unreadAlerts = 0 }) {
  const [showAddSheet, setShowAddSheet] = useStateS(false);
  const [pullY, setPullY] = useStateS(0);
  const [pulling, setPulling] = useStateS(false);
  const startY = useRefS(0);
  const scrollRef = useRefS(null);

  // Pull-to-refresh: only when scrollTop = 0
  const onTouchStart = (e) => {
    if (scrollRef.current && scrollRef.current.scrollTop <= 0) {
      startY.current = e.touches[0].clientY;
      setPulling(true);
    }
  };
  const onTouchMove = (e) => {
    if (!pulling) return;
    const dy = e.touches[0].clientY - startY.current;
    if (dy > 0) setPullY(Math.min(dy * 0.5, 80));
  };
  const onTouchEnd = () => {
    if (pulling && pullY > 50) onRefresh();
    setPulling(false);
    setPullY(0);
  };

  // Mouse fallback (for desktop demo)
  const onMouseDown = (e) => {
    if (scrollRef.current && scrollRef.current.scrollTop <= 0) {
      startY.current = e.clientY;
      setPulling(true);
      const move = (ev) => {
        const dy = ev.clientY - startY.current;
        if (dy > 0) setPullY(Math.min(dy * 0.5, 80));
      };
      const up = () => {
        window.removeEventListener('mousemove', move);
        window.removeEventListener('mouseup', up);
        if (pullY > 50) onRefresh();
        setPulling(false);
        setPullY(0);
      };
      window.addEventListener('mousemove', move);
      window.addEventListener('mouseup', up);
    }
  };

  // Greeting based on time
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

  return (
    <>
      {disconnected && <ConnectionBanner onRetry={onRefresh} />}

      {/* Greeting header (replaces standard AppBar on Home) */}
      <div style={{
        padding: '12px 16px 8px',
        display: 'flex', alignItems: 'flex-start', gap: 12,
      }}>
        <div style={{ flex: 1 }}>
          <div className="greet-name">
            {greeting}, Alex
            <span style={{ fontSize: 20 }}>👋</span>
          </div>
          <div className="greet-sub">Here's your energy overview today</div>
        </div>
        <button
          className={`appbar-icon ${refreshing ? 'spinning' : ''}`}
          onClick={onRefresh}
          aria-label="Refresh"
        >
          <span style={{ display: 'inline-block', animation: refreshing ? 'spin 0.7s linear infinite' : 'none' }}>
            <IconRefresh size={22} />
          </span>
        </button>
        <button className="appbar-icon greet-bell" onClick={onSettings} aria-label="Notifications">
          <IconBell />
          {unreadAlerts > 0 && <span className="greet-bell-dot">{unreadAlerts}</span>}
        </button>
      </div>

      {/* Pull-to-refresh indicator */}
      <div style={{
        height: pullY,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: 'var(--m3-primary)',
        transition: pulling ? 'none' : 'height 240ms ease',
        overflow: 'hidden',
      }}>
        <span style={{
          transform: `rotate(${pullY * 4}deg)`,
          animation: refreshing ? 'spin 0.7s linear infinite' : 'none',
        }}>
          <IconRefresh size={20} />
        </span>
      </div>

      <div
        className="scroll"
        ref={scrollRef}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onMouseDown={onMouseDown}
        style={{ padding: '4px 16px 24px' }}
      >
        {/* Hero energy card */}
        <EnergyHero
          kwh={energyToday}
          deltaKwh={-12}
          cost={costToday}
          costCurrency="£"
          deltaCost={-8}
          history={dayHistory}
          onReport={onShowReport}
        />

        {/* Quick access */}
        <div style={{ marginTop: 22 }}>
          <div className="section-head">
            <h2>Quick access</h2>
          </div>
          <div className="qa-row">
            <QuickTile icon={<IconDevices />} label="Devices" color="oklch(0.55 0.13 250)" onClick={() => onQuickAccess && onQuickAccess('devices-tab')} />
            <QuickTile icon={<IconSchedule />} label="Schedule" color="oklch(0.6 0.13 30)" onClick={() => onQuickAccess && onQuickAccess('schedule')} />
            <QuickTile icon={<IconWrench />} label="Maintain" color="oklch(0.55 0.13 350)" onClick={() => onQuickAccess && onQuickAccess('maintain')} />
            <QuickTile icon={<IconWarn />} label="Alerts" color="oklch(0.55 0.16 60)" onClick={() => onQuickAccess && onQuickAccess('alerts')} />
            <QuickTile icon={<IconLeaf />} label="Optimize" color="var(--m3-primary)" onClick={() => onQuickAccess && onQuickAccess('optimize')} />
          </div>
        </div>

        {/* Plugs section */}
        <div style={{ marginTop: 24 }}>
          <div className="section-head">
            <h2>Your plugs</h2>
            <span style={{ fontSize: 12, color: 'var(--m3-on-surface-variant)', fontFamily: 'var(--font-mono)' }}>
              updated {lastUpdated}
            </span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {loading
              ? <><PlugCardSkeleton /><PlugCardSkeleton /></>
              : plugs.map(plug => (
                  <PlugCard
                    key={plug.id}
                    plug={plug}
                    onToggle={onToggle}
                    onOpen={() => onOpen(plug.id)}
                  />
                ))
            }
          </div>
        </div>

        {/* Insights & Alerts */}
        <div style={{ marginTop: 24 }}>
          <div className="section-head">
            <h2>Insights &amp; alerts</h2>
            <a onClick={onAllInsights}>View all</a>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <InsightCard
              icon={<IconBolt size={18} strokeWidth={2} />}
              tint="oklch(0.6 0.16 60)"
              title="Standby draw detected"
              desc="Radio drawing 7.8 W when likely idle — about £1.20/month wasted."
              action="Check now"
              onClick={() => onQuickAccess && onQuickAccess('alerts')}
            />
            <InsightCard
              icon={<IconSchedule />}
              tint="oklch(0.55 0.13 250)"
              title="Off-peak window tonight"
              desc="Lowest tariff 00:30 – 04:30. Schedule heavy loads to save £0.12."
              action="Save £0.12"
              onClick={() => onQuickAccess && onQuickAccess('schedule')}
            />
            <InsightCard
              icon={<IconLeaf />}
              tint="var(--m3-primary)"
              title="Fridge running efficiently"
              desc="Compressor cycle is steady at 18 min — within normal range."
              onClick={() => onQuickAccess && onQuickAccess('optimize')}
            />
          </div>
        </div>

        {/* Quick info footer */}
        {!loading && (
          <div style={{
            marginTop: 18, padding: '12px 4px',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            fontSize: 11, color: 'var(--m3-on-surface-variant)', opacity: 0.7,
          }}>
            <IconLink size={12} strokeWidth={2} />
            <span style={{ fontFamily: 'var(--font-mono)' }}>100.83.45.15:8123</span>
            <span>·</span>
            <span>via Tailscale</span>
          </div>
        )}
      </div>

      {showAddSheet && (
        <div className="modal-scrim" onClick={() => setShowAddSheet(false)}>
          <div className="sheet" onClick={e => e.stopPropagation()}>
            <div className="sheet-grab" />
            <h2 style={{
              margin: '0 0 8px',
              fontFamily: 'var(--font-display)',
              fontSize: 22, fontWeight: 600,
              color: 'var(--m3-on-surface)',
            }}>Adding a new plug</h2>
            <p style={{
              margin: '0 0 18px',
              fontSize: 14, lineHeight: 1.55,
              color: 'var(--m3-on-surface-variant)',
            }}>
              Pair new SonOFF plugs in the eWeLink app, then add them to Home
              Assistant via the SonOFF LAN integration. They show up here
              automatically.
            </p>

            <ol style={{
              margin: 0, padding: 0, listStyle: 'none',
              display: 'flex', flexDirection: 'column', gap: 10,
            }}>
              {[
                ['Press the plug button for 5 s until it blinks blue.', '1'],
                ['Pair it in the eWeLink app.', '2'],
                ['In HA, Settings → Devices → SonOFF → Refresh.', '3'],
                ['Pull to refresh this screen.', '4'],
              ].map(([text, n]) => (
                <li key={n} style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                  <span style={{
                    width: 24, height: 24, borderRadius: 12,
                    background: 'var(--m3-primary-container)',
                    color: 'var(--m3-on-primary-container)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontWeight: 600, fontSize: 12,
                    flexShrink: 0,
                  }}>{n}</span>
                  <span style={{ fontSize: 14, lineHeight: 1.5, color: 'var(--m3-on-surface)', flex: 1, paddingTop: 2 }}>{text}</span>
                </li>
              ))}
            </ol>

            <button
              className="btn btn-filled"
              style={{ width: '100%', height: 48, borderRadius: 24, marginTop: 22 }}
              onClick={() => setShowAddSheet(false)}
            >
              Got it
            </button>
          </div>
        </div>
      )}
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Screen 3 — Detail
// ────────────────────────────────────────────────────────────────────────────
function DetailScreen({ plug, onBack, onToggle }) {
  const isOn = plug.state === 'on';
  const unavailable = plug.state === 'unavailable';
  const Glyph = plug.id === 'radio' ? IconRadio : IconFridge;

  // Compute derived stats
  const voltage = 228 + Math.sin(Date.now() / 8000) * 1.4;
  const current = isOn ? plug.power / voltage : 0;

  return (
    <>
      <AppBar
        leading={
          <button className="appbar-icon" onClick={onBack} aria-label="Back">
            <IconArrowBack />
          </button>
        }
        title=""
        trailing={
          <button className="appbar-icon" aria-label="Settings">
            <IconSettings />
          </button>
        }
      />

      <div className="scroll" style={{ padding: '0 20px 32px' }}>
        {/* Hero: glyph + name + big switch */}
        <div style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          padding: '8px 0 24px',
          textAlign: 'center',
        }}>
          <div style={{
            width: 96, height: 96, borderRadius: 28,
            background: isOn ? 'var(--m3-primary-container)' : 'var(--m3-surface-container-high)',
            color: isOn ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            marginBottom: 16,
            transition: 'background 280ms ease, color 280ms ease',
          }}>
            <Glyph size={52} strokeWidth={1.6} />
          </div>
          <h1 style={{
            margin: '0 0 4px',
            fontFamily: 'var(--font-display)',
            fontSize: 32, fontWeight: 600,
            letterSpacing: '-0.02em',
            color: 'var(--m3-on-surface)',
          }}>{plug.name}</h1>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            fontSize: 13, color: 'var(--m3-on-surface-variant)',
            fontFamily: 'var(--font-mono)',
          }}>
            <span className="dot" data-state={unavailable ? 'unavailable' : (isOn ? 'on' : 'off')} />
            <span>{plug.entity_id}</span>
          </div>
        </div>

        {/* Big switch panel */}
        <div style={{
          background: isOn ? 'var(--m3-primary)' : 'var(--m3-surface-container-low)',
          color: isOn ? 'var(--m3-on-primary)' : 'var(--m3-on-surface)',
          borderRadius: 24,
          padding: '20px 24px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          gap: 16,
          marginBottom: 16,
          transition: 'background 280ms ease, color 280ms ease',
        }}>
          <div style={{ minWidth: 0 }}>
            <div style={{
              fontFamily: 'var(--font-display)',
              fontSize: 22, fontWeight: 600,
              letterSpacing: '-0.01em',
            }}>
              {unavailable ? 'Unavailable' : (isOn ? 'On' : 'Off')}
            </div>
            <div style={{ fontSize: 13, opacity: 0.8, marginTop: 2, whiteSpace: 'nowrap' }}>
              {unavailable ? 'Check the device' : `Tap to turn ${isOn ? 'off' : 'on'}`}
            </div>
          </div>
          <M3Switch
            on={isOn}
            disabled={unavailable}
            onChange={() => onToggle(plug.id)}
            size="big"
            tone={isOn ? 'on-primary' : undefined}
          />
        </div>

        {/* 2×2 stat grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 10,
          marginBottom: 16,
        }}>
          <StatTile
            label="Power"
            value={unavailable ? '—' : plug.power.toFixed(1)}
            unit="W"
            icon={<IconBolt size={14} strokeWidth={2} />}
            accent
          />
          <StatTile
            label="Voltage"
            value={unavailable ? '—' : voltage.toFixed(1)}
            unit="V"
            icon={<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M6 4l-3 8h6l-3 8" /><path d="M18 4l-3 8h6l-3 8" /></svg>}
          />
          <StatTile
            label="Current"
            value={unavailable ? '—' : current.toFixed(3)}
            unit="A"
            icon={<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M4 12h4l2-7 4 14 2-7h4" /></svg>}
          />
          <StatTile
            label="Today"
            value={unavailable ? '—' : plug.energyToday.toFixed(2)}
            unit="kWh"
            icon={<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 0 1 18 0" /><path d="M3 12h18" /><path d="M12 3v18" /></svg>}
          />
        </div>

        {/* Sparkline */}
        <Sparkline
          values={plug.history}
          color="var(--m3-primary)"
          fillColor="var(--m3-primary)"
          active={isOn && !unavailable}
        />

        {/* Hint footer */}
        <div style={{
          marginTop: 20,
          padding: 14,
          background: 'var(--m3-surface-container-low)',
          borderRadius: 12,
          display: 'flex', gap: 12, alignItems: 'flex-start',
        }}>
          <IconHelp size={18} />
          <div style={{ fontSize: 12, lineHeight: 1.5, color: 'var(--m3-on-surface-variant)' }}>
            Name and icon mirror what you set in Home Assistant. Edit the entity
            there and changes show up after a refresh.
          </div>
        </div>
      </div>
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Settings sheet
// ────────────────────────────────────────────────────────────────────────────
function SettingsScreen({ url, onBack, onForget, pollSeconds, onPollChange }) {
  return (
    <>
      <AppBar
        leading={
          <button className="appbar-icon" onClick={onBack}>
            <IconArrowBack />
          </button>
        }
        title="Settings"
      />

      <div className="scroll" style={{ padding: '8px 8px 24px' }}>
        <SettingsSection title="Connection">
          <div className="settings-row" style={{ cursor: 'default' }}>
            <IconLink size={20} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 500 }}>Home Assistant</div>
              <div style={{ fontSize: 12, fontFamily: 'var(--font-mono)', color: 'var(--m3-on-surface-variant)', marginTop: 2 }}>{url}</div>
            </div>
            <span className="dot" data-state="on" />
          </div>
          <div className="settings-row" style={{ cursor: 'default' }}>
            <IconKey size={20} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 500 }}>Access token</div>
              <div style={{ fontSize: 12, fontFamily: 'var(--font-mono)', color: 'var(--m3-on-surface-variant)', marginTop: 2 }}>•••• •••• •••• 8f3a</div>
            </div>
          </div>
        </SettingsSection>

        <SettingsSection title="Refresh">
          <div style={{ padding: '4px 16px' }}>
            <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 2 }}>Poll every {pollSeconds} s</div>
            <div style={{ fontSize: 12, color: 'var(--m3-on-surface-variant)', marginBottom: 12 }}>
              Falls back to polling when WebSocket isn’t available.
            </div>
            <input
              type="range"
              min={5}
              max={60}
              step={5}
              value={pollSeconds}
              onChange={e => onPollChange(parseInt(e.target.value, 10))}
              style={{ width: '100%', accentColor: 'var(--m3-primary)' }}
            />
            <div style={{
              display: 'flex', justifyContent: 'space-between',
              fontSize: 10, fontFamily: 'var(--font-mono)',
              color: 'var(--m3-on-surface-variant)', marginTop: 2,
            }}>
              <span>5s</span><span>30s</span><span>60s</span>
            </div>
          </div>
        </SettingsSection>

        <SettingsSection title="About">
          <div className="settings-row" style={{ cursor: 'default' }}>
            <IconBolt size={20} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 500 }}>Smart Plugs</div>
              <div style={{ fontSize: 12, color: 'var(--m3-on-surface-variant)', marginTop: 2 }}>v0.1.0 · Flutter 3.22</div>
            </div>
          </div>
        </SettingsSection>

        <div style={{ padding: '24px 16px 0' }}>
          <button
            onClick={onForget}
            style={{
              width: '100%', height: 48, borderRadius: 24,
              border: '1px solid var(--m3-error)',
              background: 'transparent',
              color: 'var(--m3-error)',
              fontSize: 14, fontWeight: 500,
              cursor: 'pointer',
              fontFamily: 'inherit',
            }}
          >
            Forget instance & sign out
          </button>
        </div>
      </div>
    </>
  );
}

function SettingsSection({ title, children }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <div style={{
        padding: '14px 16px 6px',
        fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase',
        color: 'var(--m3-primary)',
        fontWeight: 600,
      }}>{title}</div>
      {children}
    </div>
  );
}

Object.assign(window, { SetupScreen, DashboardScreen, DetailScreen, SettingsScreen, InsightsScreen, DevicesScreen });

// ────────────────────────────────────────────────────────────────────────────
// Screen 4 — Insights
// ────────────────────────────────────────────────────────────────────────────
function InsightsScreen({ plugs, energyToday, costToday, weekHistory }) {
  // weekHistory: [{day:'Mon',kwh:1.2,cost:0.32}, ...]
  const maxKwh = Math.max(...weekHistory.map(d => d.kwh), 0.001);

  return (
    <>
      <AppBar title="Insights" />

      <div className="scroll" style={{ padding: '4px 16px 24px' }}>
        {/* Weekly chart card */}
        <div style={{
          background: 'var(--m3-surface-container-low)',
          borderRadius: 20,
          padding: 18,
          marginBottom: 16,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 4 }}>
            <div>
              <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase', color: 'var(--m3-on-surface-variant)' }}>This week</div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 2 }}>
                <span className="num" style={{ fontSize: 28, color: 'var(--m3-on-surface)' }}>
                  {weekHistory.reduce((s,d)=>s+d.kwh,0).toFixed(1)}
                </span>
                <span style={{ fontSize: 13, color: 'var(--m3-on-surface-variant)', fontWeight: 500 }}>kWh</span>
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: 11, color: 'var(--m3-on-surface-variant)', fontWeight: 500 }}>Cost</div>
              <div className="num" style={{ fontSize: 22, color: 'var(--m3-on-surface)', marginTop: 2 }}>
                £{weekHistory.reduce((s,d)=>s+d.cost,0).toFixed(2)}
              </div>
            </div>
          </div>

          {/* Bar chart */}
          <div style={{
            display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
            gap: 6, height: 120, marginTop: 18,
          }}>
            {weekHistory.map((d, i) => {
              const h = Math.max(4, (d.kwh / maxKwh) * 110);
              const isToday = i === weekHistory.length - 1;
              return (
                <div key={d.day} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                  <div style={{
                    width: '100%', height: h,
                    background: isToday ? 'var(--m3-primary)' : 'color-mix(in oklab, var(--m3-primary) 35%, var(--m3-surface-container-high))',
                    borderRadius: '6px 6px 4px 4px',
                    transition: 'height 320ms ease',
                  }} />
                  <span style={{
                    fontSize: 10, fontFamily: 'var(--font-mono)',
                    color: isToday ? 'var(--m3-primary)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isToday ? 700 : 500,
                  }}>{d.day}</span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Top appliances */}
        <div className="section-head">
          <h2>Top appliances today</h2>
        </div>
        <div style={{
          background: 'var(--m3-surface-container-low)',
          borderRadius: 16,
          padding: '8px 14px',
          marginBottom: 16,
        }}>
          {plugs.map((p, i) => {
            const total = plugs.reduce((s,x)=>s+x.energyToday,0) || 1;
            const pct = Math.round((p.energyToday / total) * 100);
            const Glyph = p.id === 'radio' ? IconRadio : IconFridge;
            return (
              <div key={p.id} style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '12px 0',
                borderBottom: i < plugs.length - 1 ? '0.5px solid var(--m3-outline-variant)' : 'none',
              }}>
                <div style={{
                  width: 36, height: 36, borderRadius: 10,
                  background: 'var(--m3-primary-container)',
                  color: 'var(--m3-on-primary-container)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  flexShrink: 0,
                }}>
                  <Glyph size={20} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
                    fontSize: 14, fontWeight: 500, color: 'var(--m3-on-surface)',
                    marginBottom: 4,
                  }}>
                    <span>{p.name}</span>
                    <span className="num" style={{ fontSize: 13, color: 'var(--m3-on-surface-variant)' }}>
                      {p.energyToday.toFixed(2)} kWh
                    </span>
                  </div>
                  <div style={{
                    height: 6, borderRadius: 3,
                    background: 'var(--m3-surface-container-high)',
                    overflow: 'hidden',
                  }}>
                    <div style={{
                      height: '100%', width: `${pct}%`,
                      background: 'var(--m3-primary)',
                      borderRadius: 3,
                      transition: 'width 400ms ease',
                    }} />
                  </div>
                </div>
                <div style={{
                  fontSize: 12, fontWeight: 600,
                  color: 'var(--m3-primary)',
                  fontVariantNumeric: 'tabular-nums',
                  minWidth: 36, textAlign: 'right',
                }}>{pct}%</div>
              </div>
            );
          })}
        </div>

        {/* Tips */}
        <div className="section-head"><h2>Recommendations</h2></div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <InsightCard
            icon={<IconWrench />}
            tint="oklch(0.6 0.16 30)"
            title="Predictive maintenance"
            desc="Fridge compressor cycle drifting slightly longer. Service within 30 days."
            action="High"
            actionColor="oklch(0.6 0.16 30)"
          />
          <InsightCard
            icon={<IconSchedule />}
            tint="oklch(0.55 0.13 250)"
            title="Schedule suggestion"
            desc="Run heavy loads 00:30 – 04:30 to use off-peak tariff."
            action="Save £0.12"
            actionColor="oklch(0.55 0.13 250)"
          />
          <InsightCard
            icon={<IconBolt size={18} strokeWidth={2} />}
            tint="oklch(0.6 0.16 60)"
            title="Energy loss detected"
            desc="Standby power loss of 0.8 kWh/day detected across all devices."
            action="Check now"
            actionColor="oklch(0.6 0.16 60)"
          />
          <InsightCard
            icon={<IconLeaf />}
            tint="var(--m3-primary)"
            title="Optimization tip"
            desc="Setting fridge to 4°C can save up to 8% energy without affecting freshness."
            action="Learn more"
            actionColor="var(--m3-primary)"
          />
        </div>
      </div>
    </>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Screen 5 — Devices (simple list, lighter than Home)
// ────────────────────────────────────────────────────────────────────────────
function DevicesScreen({ plugs, onToggle, onOpen }) {
  return (
    <>
      <AppBar title="Devices" />
      <div className="scroll" style={{ padding: '0 16px 24px' }}>
        <div style={{
          padding: '0 4px 12px',
          fontSize: 13, color: 'var(--m3-on-surface-variant)',
        }}>
          {plugs.filter(p=>p.state==='on').length} of {plugs.length} on · synced from Home Assistant
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {plugs.map(plug => (
            <PlugCard key={plug.id} plug={plug} onToggle={onToggle} onOpen={() => onOpen(plug.id)} />
          ))}
        </div>

        <div style={{
          marginTop: 24,
          padding: 16,
          background: 'var(--m3-surface-container-low)',
          borderRadius: 16,
          textAlign: 'center',
        }}>
          <div style={{ fontSize: 13, color: 'var(--m3-on-surface-variant)', marginBottom: 10 }}>
            Need to add another plug? Use the <b>+</b> tab below.
          </div>
        </div>
      </div>
    </>
  );
}
