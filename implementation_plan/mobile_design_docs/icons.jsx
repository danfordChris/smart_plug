// icons.jsx — Material-style icons + custom appliance glyphs
// All icons sized 24x24 viewBox; consumers control size via width/height.

const Icon = ({ children, size = 24, color = 'currentColor', fill = false, strokeWidth = 2 }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill={fill ? color : 'none'}
    stroke={fill ? 'none' : color}
    strokeWidth={strokeWidth}
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
  >
    {children}
  </svg>
);

// ─── Generic Material-style icons ───
const IconRefresh = (p) => (
  <Icon {...p}>
    <path d="M3 12a9 9 0 0 1 15.5-6.3L21 8" />
    <path d="M21 3v5h-5" />
    <path d="M21 12a9 9 0 0 1-15.5 6.3L3 16" />
    <path d="M3 21v-5h5" />
  </Icon>
);

const IconSettings = (p) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.7 1.7 0 0 0 .34 1.87l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.7 1.7 0 0 0-1.87-.34 1.7 1.7 0 0 0-1.03 1.56V21a2 2 0 1 1-4 0v-.09a1.7 1.7 0 0 0-1.11-1.56 1.7 1.7 0 0 0-1.87.34l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.7 1.7 0 0 0 .34-1.87 1.7 1.7 0 0 0-1.56-1.03H3a2 2 0 1 1 0-4h.09A1.7 1.7 0 0 0 4.65 9a1.7 1.7 0 0 0-.34-1.87l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.7 1.7 0 0 0 1.87.34H9a1.7 1.7 0 0 0 1.03-1.56V3a2 2 0 1 1 4 0v.09c0 .67.4 1.28 1.03 1.56a1.7 1.7 0 0 0 1.87-.34l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.7 1.7 0 0 0-.34 1.87V9c.28.63.89 1.03 1.56 1.03H21a2 2 0 1 1 0 4h-.09c-.67 0-1.28.4-1.51 1z" />
  </Icon>
);

const IconChevronRight = (p) => (
  <Icon {...p}><path d="M9 6l6 6-6 6" /></Icon>
);

const IconArrowBack = (p) => (
  <Icon {...p}><path d="M19 12H5" /><path d="M12 19l-7-7 7-7" /></Icon>
);

const IconCheck = (p) => (
  <Icon {...p}><path d="M5 12l5 5 9-11" /></Icon>
);

const IconClose = (p) => (
  <Icon {...p}><path d="M6 6l12 12M18 6L6 18" /></Icon>
);

const IconAlert = (p) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="10" />
    <path d="M12 8v4M12 16h.01" />
  </Icon>
);

const IconEye = (p) => (
  <Icon {...p}>
    <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" />
    <circle cx="12" cy="12" r="3" />
  </Icon>
);

const IconEyeOff = (p) => (
  <Icon {...p}>
    <path d="M3 3l18 18" />
    <path d="M10.6 6.1A10.9 10.9 0 0 1 12 6c6.5 0 10 7 10 7a16.4 16.4 0 0 1-3.5 4.3" />
    <path d="M6.6 6.7A16.4 16.4 0 0 0 2 13s3.5 7 10 7c1.4 0 2.7-.3 3.9-.7" />
    <path d="M9.9 9.9A3 3 0 0 0 14.1 14.1" />
  </Icon>
);

const IconPlus = (p) => (
  <Icon {...p}><path d="M12 5v14M5 12h14" /></Icon>
);

const IconBolt = (p) => (
  <Icon {...p}><path d="M13 2L4 14h7l-1 8 9-12h-7l1-8z" /></Icon>
);

const IconWifi = (p) => (
  <Icon {...p}>
    <path d="M5 12.55a11 11 0 0 1 14 0" />
    <path d="M8.5 16.05a6 6 0 0 1 7 0" />
    <path d="M2 8.82a15 15 0 0 1 20 0" />
    <path d="M12 20h.01" />
  </Icon>
);

const IconCloudOff = (p) => (
  <Icon {...p}>
    <path d="M2 2l20 20" />
    <path d="M5.8 5.8A6 6 0 0 0 9 17h9" />
    <path d="M17.5 17.5A4 4 0 0 0 18 9.5a7.5 7.5 0 0 0-10.6-3" />
  </Icon>
);

const IconHelp = (p) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="10" />
    <path d="M9.1 9a3 3 0 1 1 5.8 1c0 2-3 3-3 3" />
    <path d="M12 17h.01" />
  </Icon>
);

const IconLink = (p) => (
  <Icon {...p}>
    <path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1" />
    <path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1" />
  </Icon>
);

const IconKey = (p) => (
  <Icon {...p}>
    <circle cx="7" cy="14" r="4" />
    <path d="M10 11l10-10M16 5l3 3M14 7l3 3" />
  </Icon>
);

// ─── Appliance glyphs — custom drawn, simple geometric ───
const IconRadio = ({ size = 24, color = 'currentColor', strokeWidth = 1.8 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
    {/* antenna */}
    <path d="M7 3l11 4" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
    {/* body */}
    <rect x="2.5" y="7" width="19" height="13.5" rx="2.5" stroke={color} strokeWidth={strokeWidth} fill="none" />
    {/* speaker grill */}
    <circle cx="16.5" cy="13.5" r="3.2" stroke={color} strokeWidth={strokeWidth} fill="none" />
    <circle cx="16.5" cy="13.5" r="1.1" stroke={color} strokeWidth={strokeWidth} fill="none" />
    {/* dial bar */}
    <path d="M5 10.5h6" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
    {/* tuning dot */}
    <circle cx="7" cy="14.5" r="0.9" fill={color} />
    <circle cx="9.5" cy="14.5" r="0.9" fill={color} opacity="0.4" />
    <path d="M5 17h6" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" opacity="0.5" />
  </svg>
);

const IconFridge = ({ size = 24, color = 'currentColor', strokeWidth = 1.8 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
    {/* body */}
    <rect x="5" y="2.5" width="14" height="19" rx="2.2" stroke={color} strokeWidth={strokeWidth} fill="none" />
    {/* divider */}
    <path d="M5 9h14" stroke={color} strokeWidth={strokeWidth} />
    {/* handles */}
    <path d="M7.5 5.5v2" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
    <path d="M7.5 11.5v3.5" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
  </svg>
);

// Power icon (for sparkline)
const IconTrend = (p) => (
  <Icon {...p}>
    <path d="M3 17l6-6 4 4 8-8" />
    <path d="M14 7h7v7" />
  </Icon>
);

Object.assign(window, {
  Icon, IconRefresh, IconSettings, IconChevronRight, IconArrowBack,
  IconCheck, IconClose, IconAlert, IconEye, IconEyeOff, IconPlus, IconBolt,
  IconWifi, IconCloudOff, IconHelp, IconLink, IconKey,
  IconRadio, IconFridge, IconTrend,
});
