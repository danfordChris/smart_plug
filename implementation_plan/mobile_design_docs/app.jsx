// app.jsx — Main App: state, navigation, simulated HA data, Tweaks panel

const { useState: useStateA, useEffect: useEffectA, useRef: useRefA, useMemo: useMemoA, useCallback: useCallbackA } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "light",
  "primaryHue": 155,
  "screen": "dashboard",
  "deviceOS": "ios",
  "liveData": true,
  "showOnboarding": false,
  "simulateOffline": false,
  "simulateToggleError": false,
  "simulateUnavailable": false
}/*EDITMODE-END*/;

// ─── Seed plug data ─────────────────────────────────────────────────────────
function initialPlugs() {
  const radioHist = Array.from({ length: 60 }, (_, i) => {
    // Steady-ish around 8W, occasional spikes
    const base = 7.8 + Math.sin(i * 0.5) * 0.6;
    const spike = (i === 28 || i === 41) ? 3 : 0;
    return Math.max(0, base + spike);
  });
  const fridgeHist = Array.from({ length: 60 }, (_, i) => {
    // Compressor cycles ~every 15 minutes
    const cycle = Math.sin((i / 15) * Math.PI);
    const compressor = cycle > 0.3 ? 110 + cycle * 30 : 4 + cycle * 2;
    return Math.max(0, compressor);
  });
  return [
    {
      id: 'radio',
      entity_id: 'switch.radio',
      name: 'Radio',
      state: 'on',
      power: 8.2,
      voltage: 229.4,
      current: 0.036,
      energyToday: 0.18,
      history: radioHist,
    },
    {
      id: 'fridge',
      entity_id: 'switch.fridge',
      name: 'Fridge',
      state: 'on',
      power: 124.6,
      voltage: 229.1,
      current: 0.544,
      energyToday: 1.42,
      history: fridgeHist,
    },
  ];
}

function App() {
  return (
    <SnackbarProvider>
      <AppInner />
    </SnackbarProvider>
  );
}

function AppInner() {
  const snack = useSnackbar();
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  // ─── App state ───
  const [route, setRoute] = useStateA(() => t.screen);   // 'setup' | 'dashboard' | 'detail' | 'settings'
  const [prevRoute, setPrevRoute] = useStateA(null);
  const [selectedPlug, setSelectedPlug] = useStateA('fridge');
  const [plugs, setPlugs] = useStateA(initialPlugs);
  const [refreshing, setRefreshing] = useStateA(false);
  const [loading, setLoading] = useStateA(false);
  const [pollSeconds, setPollSeconds] = useStateA(10);
  const [lastUpdated, setLastUpdated] = useStateA('just now');
  const [savedUrl] = useStateA('http://100.83.45.15:8123');
  const [mainTab, setMainTab] = useStateA('home'); // 'home' | 'devices' | 'insights' | 'profile'
  const [showAddSheet, setShowAddSheet] = useStateA(false);
  // Sub-routes accessible from Home (quick access tiles, bell, etc.)
  const [subRoute, setSubRoute] = useStateA(null);   // null | 'schedule' | 'maintain' | 'alerts' | 'optimize' | 'notifications' | 'add'
  const [alerts, setAlerts] = useStateA(() => [
    { id: 'a1', icon: <IconBolt size={18} strokeWidth={2} />, tint: 'oklch(0.6 0.16 60)', title: 'Standby draw detected', desc: 'Radio drawing 7.8 W idle — about £1.20/month.', time: '2m', unread: true },
    { id: 'a2', icon: <IconSchedule />, tint: 'oklch(0.55 0.13 250)', title: 'Off-peak window starts soon', desc: 'Cheaper tariff 00:30 – 04:30. Run heavy loads now.', time: '1h', unread: true },
    { id: 'a3', icon: <IconWrench />, tint: 'oklch(0.6 0.16 30)', title: 'Fridge service due', desc: 'Compressor cycle drifting. Book service within 30 days.', time: 'Yesterday', unread: false },
  ]);
  const unreadAlerts = alerts.filter(a => a.unread).length;

  // ─── Derived aggregates for hero card + insights ───
  const energyToday = useMemoA(
    () => plugs.reduce((s, p) => s + p.energyToday, 0) + 17.1, // include "other appliances" baseline
    [plugs]
  );
  const costToday = useMemoA(
    () => energyToday * 0.27, // £0.27/kWh tariff
    [energyToday]
  );
  const dayHistory = useMemoA(() => {
    const pts = [];
    for (let h = 0; h < 24; h++) {
      let v = 0.4;
      v += 0.25 * Math.exp(-Math.pow((h - 8) / 2.5, 2));
      v += 0.45 * Math.exp(-Math.pow((h - 19) / 2.8, 2));
      v += 0.06 * Math.sin(h * 1.7);
      pts.push(Math.max(0.1, v));
    }
    return pts;
  }, []);
  const weekHistory = useMemoA(() => {
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const seed = [16.4, 18.1, 15.2, 19.8, 17.6, 14.5, energyToday];
    return days.map((d, i) => ({ day: d, kwh: seed[i], cost: seed[i] * 0.27 }));
  }, [energyToday]);

  // Sync route when tweaks change screen
  useEffectA(() => { if (t.screen !== route) navigate(t.screen); }, [t.screen]);

  // Apply theme class + primary hue to root
  useEffectA(() => {
    document.documentElement.classList.toggle('theme-dark', t.theme === 'dark');
    document.documentElement.style.setProperty('--m3-primary-h', String(t.primaryHue));
  }, [t.theme, t.primaryHue]);

  // ─── Apply "simulate unavailable" tweak ───
  useEffectA(() => {
    setPlugs(prev => prev.map((p, i) => {
      if (t.simulateUnavailable && i === 0) {
        return { ...p, state: 'unavailable' };
      }
      // Restore to 'on' if it was previously unavailable due to the tweak
      if (!t.simulateUnavailable && p.state === 'unavailable') {
        return { ...p, state: 'on', power: p.id === 'fridge' ? 124 : 8 };
      }
      return p;
    }));
  }, [t.simulateUnavailable]);

  // ─── Live data simulation ───
  useEffectA(() => {
    if (!t.liveData) return;
    const id = setInterval(() => {
      setPlugs(prev => prev.map(p => {
        if (p.state !== 'on') return p;
        let newPower;
        if (p.id === 'radio') {
          newPower = Math.max(0, 8 + Math.sin(Date.now() / 4000) * 0.8 + (Math.random() - 0.5) * 0.4);
        } else {
          const cycle = Math.sin(Date.now() / 90000) + Math.sin(Date.now() / 18000) * 0.3;
          newPower = cycle > 0.1 ? 115 + cycle * 18 + (Math.random() - 0.5) * 4 : 4 + Math.random() * 2;
        }
        const history = [...p.history.slice(1), newPower];
        const energyToday = p.energyToday + (newPower / 1000) * (1.5 / 3600);
        const voltage = 228.5 + Math.sin(Date.now() / 11000) * 1.5;
        const current = newPower / voltage;
        return { ...p, power: newPower, history, energyToday, voltage, current };
      }));
    }, 1500);
    return () => clearInterval(id);
  }, [t.liveData]);

  // "Last updated" timer
  useEffectA(() => {
    const id = setInterval(() => {
      setLastUpdated(prev => {
        // Simple relative timestamp text that rolls
        const t0 = window.__lastFetchAt || Date.now();
        const secs = Math.floor((Date.now() - t0) / 1000);
        if (secs < 5) return 'just now';
        if (secs < 60) return secs + 's ago';
        return Math.floor(secs / 60) + 'm ago';
      });
    }, 1000);
    return () => clearInterval(id);
  }, []);

  // ─── Navigation ───
  const navigate = useCallbackA((to) => {
    setPrevRoute(route);
    setRoute(to);
    if (to === 'dashboard' || to === 'setup') {
      setTweak('screen', to);
    }
  }, [route, setTweak]);

  // ─── Handlers ───
  const handleToggle = (plugId) => {
    const target = plugs.find(p => p.id === plugId);
    if (!target || target.state === 'unavailable') {
      snack.show({ text: 'Plug is unavailable', kind: 'error', duration: 2500 });
      return;
    }
    const isOn = target.state === 'on';
    const newState = isOn ? 'off' : 'on';
    const newPower = newState === 'on' ? (plugId === 'fridge' ? 4 : 7.5) : 0;

    // Optimistic update
    setPlugs(prev => prev.map(p => p.id === plugId ? { ...p, state: newState, power: newPower } : p));

    // If simulating error: revert after a moment and snackbar
    if (t.simulateToggleError) {
      setTimeout(() => {
        setPlugs(prev => prev.map(p => p.id === plugId ? { ...p, state: target.state, power: target.power } : p));
        snack.show({
          text: "Couldn't reach Home Assistant",
          kind: 'error',
          actionLabel: 'Retry',
          onAction: () => handleToggle(plugId),
          duration: 5000,
        });
      }, 600);
    }
  };

  const handleRefresh = () => {
    setRefreshing(true);
    window.__lastFetchAt = Date.now();
    setLastUpdated('just now');
    if (t.simulateOffline) {
      setTimeout(() => {
        setRefreshing(false);
        snack.show({
          text: "Couldn't reach Home Assistant — check connection",
          kind: 'error',
          actionLabel: 'Retry',
          onAction: handleRefresh,
        });
      }, 1200);
      return;
    }
    setTimeout(() => {
      setRefreshing(false);
      snack.show({ text: 'Refreshed', duration: 1600 });
    }, 900);
  };

  const handleOpenPlug = (plugId) => {
    setSelectedPlug(plugId);
    navigate('detail');
  };

  // Determine animation direction for screen transitions
  const screenOrder = { setup: 0, dashboard: 1, detail: 2, settings: 3 };
  const direction = prevRoute && screenOrder[route] > screenOrder[prevRoute] ? 'r' : 'l';

  const currentPlug = plugs.find(p => p.id === selectedPlug) || plugs[0];

  // ─── Render current screen ───
  const isMainRoute = route === 'dashboard';

  const renderMainTab = () => {
    // Sub-routes (reached from Home: quick access, bell, "View all", etc.)
    if (subRoute === 'schedule') return <ScheduleScreen onBack={() => setSubRoute(null)} plugs={plugs} snack={snack} />;
    if (subRoute === 'maintain') return <MaintainScreen onBack={() => setSubRoute(null)} plugs={plugs} />;
    if (subRoute === 'alerts')   return <AlertsScreen   onBack={() => setSubRoute(null)} alerts={alerts}
                                          onClearAll={() => setAlerts(a => a.map(x => ({ ...x, unread: false })))}
                                          snack={snack} />;
    if (subRoute === 'optimize') return <OptimizeScreen onBack={() => setSubRoute(null)} />;
    if (subRoute === 'notifications') return <NotificationsScreen onBack={() => setSubRoute(null)} alerts={alerts}
                                          onClearAll={() => setAlerts(a => a.map(x => ({ ...x, unread: false })))}
                                          snack={snack} />;
    if (subRoute === 'add')      return <AddDeviceScreen onBack={() => setSubRoute(null)} snack={snack} />;

    if (mainTab === 'devices') {
      return <DevicesScreen plugs={plugs} onToggle={handleToggle} onOpen={handleOpenPlug} />;
    }
    if (mainTab === 'insights') {
      return <InsightsScreen plugs={plugs} energyToday={energyToday} costToday={costToday} weekHistory={weekHistory} />;
    }
    if (mainTab === 'profile') {
      return (
        <SettingsScreen
          url={savedUrl}
          pollSeconds={pollSeconds}
          onPollChange={setPollSeconds}
          onBack={() => setMainTab('home')}
          onForget={() => navigate('setup')}
        />
      );
    }
    return (
      <DashboardScreen
        plugs={plugs}
        onToggle={handleToggle}
        onOpen={handleOpenPlug}
        onSettings={() => setSubRoute('notifications')}
        onRefresh={handleRefresh}
        refreshing={refreshing}
        disconnected={t.simulateOffline}
        loading={loading}
        lastUpdated={lastUpdated}
        energyToday={energyToday}
        costToday={costToday}
        dayHistory={dayHistory}
        unreadAlerts={unreadAlerts}
        onShowReport={() => setMainTab('insights')}
        onQuickAccess={(key) => {
          if (key === 'devices-tab') { setMainTab('devices'); return; }
          setSubRoute(key);
        }}
        onAllInsights={() => setSubRoute('alerts')}
      />
    );
  };

  const renderScreen = () => {
    if (route === 'setup') {
      return (
        <SetupScreen
          initialUrl={savedUrl}
          initialToken=""
          onSave={() => navigate('dashboard')}
          onCancel={prevRoute ? () => navigate('dashboard') : null}
        />
      );
    }
    if (route === 'detail') {
      return (
        <DetailScreen
          plug={currentPlug}
          onBack={() => navigate('dashboard')}
          onToggle={handleToggle}
        />
      );
    }
    if (route === 'settings') {
      return (
        <SettingsScreen
          url={savedUrl}
          pollSeconds={pollSeconds}
          onPollChange={setPollSeconds}
          onBack={() => navigate('dashboard')}
          onForget={() => navigate('setup')}
        />
      );
    }
    // dashboard / main route with bottom nav
    return (
      <>
        <div style={{ flex: 1, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          {renderMainTab()}
        </div>
        <BottomNav
          active={subRoute ? null : mainTab}
          onChange={(tab) => { setSubRoute(null); setMainTab(tab); }}
          onAdd={() => setSubRoute('add')}
        />
      </>
    );
  };

  // ─── Phone frame ───
  const DeviceFrame = t.deviceOS === 'android' ? window.AndroidDevice : window.IOSDevice;
  const darkChrome = t.theme === 'dark';

  return (
    <div className="stage" data-screen-label={`App / ${route}${isMainRoute ? '/' + mainTab : ''}`}>
      <DeviceFrame width={402} height={874} dark={darkChrome}>
        <div className="app-shell">
          {renderScreen()}

          {/* Global Add-device sheet */}
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
        </div>
      </DeviceFrame>

      {/* Tweaks panel */}
      <TweaksPanel>
        <TweakSection label="View" />
        <TweakSelect
          label="Screen"
          value={route === 'dashboard' ? `main:${mainTab}` : route}
          options={[
            { value: 'setup', label: '1 · Setup' },
            { value: 'main:home', label: '2a · Home' },
            { value: 'main:devices', label: '2b · Devices' },
            { value: 'main:insights', label: '2c · Insights' },
            { value: 'main:profile', label: '2d · Settings' },
            { value: 'detail', label: '3 · Detail' },
          ]}
          onChange={(v) => {
            if (v.startsWith('main:')) {
              setMainTab(v.slice(5));
              if (route !== 'dashboard') navigate('dashboard');
              setTweak('screen', 'dashboard');
            } else {
              setTweak('screen', v);
              navigate(v);
            }
          }}
        />
        <TweakRadio
          label="Device"
          value={t.deviceOS}
          options={[
            { value: 'ios', label: 'iOS' },
            { value: 'android', label: 'Android' },
          ]}
          onChange={(v) => setTweak('deviceOS', v)}
        />
        <TweakRadio
          label="Theme"
          value={t.theme}
          options={[
            { value: 'light', label: 'Light' },
            { value: 'dark', label: 'Dark' },
          ]}
          onChange={(v) => setTweak('theme', v)}
        />

        <TweakSection label="Brand" />
        <TweakColor
          label="Primary"
          value={t.primaryHue}
          options={[
            { value: 155, swatch: 'oklch(0.55 0.13 155)' },  // forest green (default)
            { value: 185, swatch: 'oklch(0.48 0.085 185)' }, // teal
            { value: 250, swatch: 'oklch(0.48 0.085 250)' }, // indigo
            { value: 35,  swatch: 'oklch(0.55 0.13 35)' },   // amber
            { value: 350, swatch: 'oklch(0.55 0.13 350)' },  // magenta
          ]}
          onChange={(v) => setTweak('primaryHue', v)}
        />

        <TweakSection label="Data" />
        <TweakToggle
          label="Live readings"
          value={t.liveData}
          onChange={(v) => setTweak('liveData', v)}
        />

        <TweakSection label="Error states" />
        <TweakToggle
          label="Simulate offline"
          value={t.simulateOffline}
          onChange={(v) => setTweak('simulateOffline', v)}
        />
        <TweakToggle
          label="Toggle fails (HA unreachable)"
          value={t.simulateToggleError}
          onChange={(v) => setTweak('simulateToggleError', v)}
        />
        <TweakToggle
          label="Radio plug unavailable"
          value={t.simulateUnavailable}
          onChange={(v) => setTweak('simulateUnavailable', v)}
        />
        <TweakButton label="Pull to refresh" onClick={handleRefresh} />

        <TweakSection label="Handoff" />
        <TweakButton
          label="Open Flutter handoff doc"
          onClick={() => window.open('Flutter Handoff.md', '_blank')}
        />
      </TweaksPanel>
    </div>
  );
}

// Bespoke <TweakColor> that takes {value, swatch} for non-string values (hue)
function TweakColor({ label, value, options, onChange }) {
  return (
    <div className="twk-row">
      <div className="twk-lbl"><span>{label}</span></div>
      <div style={{ display: 'flex', gap: 8 }}>
        {options.map((opt, i) => {
          const selected = opt.value === value;
          return (
            <button
              key={i}
              onClick={() => onChange(opt.value)}
              style={{
                width: 28, height: 28, borderRadius: '50%',
                border: selected ? '2px solid #29261b' : '1px solid rgba(0,0,0,0.12)',
                background: opt.swatch,
                cursor: 'pointer',
                padding: 0,
                outline: 'none',
              }}
              aria-label={`Color ${i}`}
            />
          );
        })}
      </div>
    </div>
  );
}

// Bespoke <TweakSelect> that accepts {value,label}
function TweakSelect({ label, value, options, onChange }) {
  return (
    <div className="twk-row">
      <div className="twk-lbl"><span>{label}</span></div>
      <select
        className="twk-field"
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        {options.map(opt => (
          <option key={opt.value} value={opt.value}>{opt.label}</option>
        ))}
      </select>
    </div>
  );
}

// Bespoke <TweakRadio> for object options
function TweakRadio({ label, value, options, onChange }) {
  return (
    <div className="twk-row">
      <div className="twk-lbl"><span>{label}</span></div>
      <div style={{
        display: 'flex',
        background: 'rgba(0,0,0,0.06)',
        borderRadius: 8, padding: 2,
      }}>
        {options.map(opt => {
          const sel = opt.value === value;
          return (
            <button
              key={opt.value}
              onClick={() => onChange(opt.value)}
              style={{
                flex: 1, height: 22,
                border: 0,
                borderRadius: 6,
                background: sel ? '#fff' : 'transparent',
                boxShadow: sel ? '0 1px 2px rgba(0,0,0,0.1)' : 'none',
                fontSize: 11, fontWeight: sel ? 600 : 500,
                color: '#29261b',
                cursor: 'pointer',
                padding: 0,
                fontFamily: 'inherit',
              }}
            >
              {opt.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

// Override globals with our local versions
Object.assign(window, { TweakColor, TweakSelect, TweakRadio });

// ─── Mount ───
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
