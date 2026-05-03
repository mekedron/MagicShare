// Features grid + multi-device fan-out hero card.

import {
  DevicesIcon,
  LockIcon,
  BellIcon,
  WifiIcon,
  ArrowIcon,
  CloudIcon,
} from './Icons';

const styles = {
  section: {paddingTop: 24, paddingBottom: 96},
  header: {textAlign: 'center', maxWidth: 760, margin: '0 auto 56px'},
  h2: {fontSize: 'clamp(36px, 5vw, 64px)', marginTop: 12},
  sub: {color: 'var(--ink-2)', marginTop: 18, fontSize: 16, lineHeight: 1.55},
  grid: {
    display: 'grid',
    gridTemplateColumns: '1.4fr 1fr 1fr',
    gridTemplateRows: 'auto auto',
    gap: 20,
  },
  cell: {padding: 26, display: 'flex', flexDirection: 'column', gap: 14},
  cellTitle: {color: 'var(--ink-0)', fontSize: 18, fontWeight: 500, letterSpacing: '-0.01em'},
  cellBody: {color: 'var(--ink-2)', fontSize: 14, lineHeight: 1.55, margin: 0},
  iconWrap: {
    width: 36,
    height: 36,
    borderRadius: 9,
    border: '1px solid color-mix(in oklch, var(--spark) 50%, var(--line))',
    display: 'grid',
    placeItems: 'center',
    color: 'var(--spark)',
    background: 'color-mix(in oklch, var(--spark) 14%, var(--bg-1))',
    boxShadow: '0 0 18px color-mix(in oklch, var(--spark) 18%, transparent) inset',
  },
};

function FanOutDiagram() {
  return (
    <div
      style={{
        position: 'relative',
        height: 240,
        borderRadius: 14,
        border: '1px solid var(--line-soft)',
        background: 'color-mix(in oklch, var(--bg-2) 50%, transparent)',
        overflow: 'hidden',
      }}>
      <span
        className="mono"
        style={{
          position: 'absolute',
          top: 12,
          left: 14,
          fontSize: 10,
          letterSpacing: '0.18em',
          color: 'var(--ink-3)',
        }}>
        FAN-OUT · 1 SEND, 4 DEVICES
      </span>

      <svg viewBox="0 0 480 240" width="100%" height="100%">
        <defs>
          <path id="ms-f1" d="M 60 180 C 130 100, 200 80, 240 60" />
          <path id="ms-f2" d="M 60 180 C 160 140, 240 120, 320 110" />
          <path id="ms-f3" d="M 60 180 C 200 200, 280 200, 380 170" />
          <path id="ms-f4" d="M 60 180 C 200 220, 320 220, 420 220" />
        </defs>

        {[1, 2, 3, 4].map((i) => (
          <use key={i} href={`#ms-f${i}`} stroke="var(--line)" strokeDasharray="2 5" fill="none" />
        ))}

        <g transform="translate(40, 162)">
          <rect width="44" height="32" rx="5" fill="var(--device-fill)" stroke="var(--line)" />
          <text
            x="22"
            y="50"
            textAnchor="middle"
            fill="var(--ink-3)"
            style={{font: "500 9px 'Geist Mono',monospace", letterSpacing: '0.14em'}}>
            YOU
          </text>
        </g>

        {[
          {x: 224, y: 44, w: 32, h: 32, label: 'MAC', fill: 'var(--device-fill)', screen: 'var(--device-screen)'},
          {x: 304, y: 94, w: 32, h: 28, label: 'iPAD', fill: 'var(--device-fill-2)', screen: 'var(--device-screen-2)'},
          {x: 364, y: 154, w: 26, h: 36, label: 'PIXEL', fill: 'var(--device-fill-3)', screen: 'var(--device-screen-3)'},
          {x: 404, y: 204, w: 26, h: 32, label: 'WIN', fill: 'var(--device-fill)', screen: 'var(--device-screen)'},
        ].map((t, i) => (
          <g key={i} transform={`translate(${t.x}, ${t.y})`}>
            <rect width={t.w} height={t.h} rx="4" fill={t.fill} stroke="var(--line)" />
            <rect x="2" y="2" width={t.w - 4} height={t.h - 4} rx="3" fill={t.screen} />
            <text
              x={t.w / 2}
              y={t.h + 12}
              textAnchor="middle"
              fill="var(--ink-3)"
              style={{font: "500 9px 'Geist Mono',monospace", letterSpacing: '0.14em'}}>
              {t.label}
            </text>
          </g>
        ))}

        {[
          {p: 'M 60 180 C 130 100, 200 80, 240 60', d: 0, c: 'oklch(82% 0.16 75)'},
          {p: 'M 60 180 C 160 140, 240 120, 320 110', d: 0.15, c: 'oklch(72% 0.18 295)'},
          {p: 'M 60 180 C 200 200, 280 200, 380 170', d: 0.3, c: 'oklch(82% 0.16 200)'},
          {p: 'M 60 180 C 200 220, 320 220, 420 220', d: 0.45, c: 'oklch(82% 0.16 75)'},
        ].map((s, i) => (
          <circle
            key={i}
            r="3.5"
            fill={s.c}
            style={{
              offsetPath: `path('${s.p}')`,
              filter: `drop-shadow(0 0 6px ${s.c})`,
              animation: `fan-spark 3.5s ease-in-out ${s.d}s infinite`,
            }}
          />
        ))}

        <style>{`
          @keyframes fan-spark {
            0%,5%   { offset-distance: 0%; opacity: 0; }
            12%     { opacity: 1; }
            85%     { offset-distance: 100%; opacity: 1; }
            100%    { offset-distance: 100%; opacity: 0; }
          }
        `}</style>
      </svg>
    </div>
  );
}

export default function Features() {
  const cells = [
    {
      span: 'wide',
      title: 'One send. Every device.',
      body:
        'Fan out a file to your phone, laptop, tablet — all at once, in parallel. No queueing, no doing it four times.',
      diagram: <FanOutDiagram />,
      icon: <DevicesIcon />,
    },
    {
      title: 'End-to-end encrypted',
      body:
        'Files are scrambled with a key only your devices share. Even we couldn’t read them if we wanted to.',
      icon: <LockIcon />,
    },
    {
      title: 'Works in the background',
      body:
        'You don’t have to open the app on the other side first. Send, tap the notification, done.',
      icon: <BellIcon />,
    },
    {
      title: 'Works on any network',
      body:
        'Same Wi-Fi, different Wi-Fi, or mobile data — as long as both devices have internet, you’re good.',
      icon: <WifiIcon />,
    },
    {
      title: 'Send links, not just files',
      body:
        'Paste a URL on one device, tap the notification on another, and the link opens in the default browser.',
      icon: <ArrowIcon />,
    },
    {
      title: 'Compatible with LocalSend',
      body:
        'Cloud features are additive. A MagicShare device can still send to a stock LocalSend device on the same LAN.',
      icon: <CloudIcon />,
    },
  ];

  return (
    <section className="section" id="features" style={styles.section}>
      <div className="wrap">
        <div style={styles.header}>
          <span className="eyebrow">What you get</span>
          <h2 className="display" style={styles.h2}>
            Built for the{' '}
            <span className="upright" style={{color: 'var(--beam)'}}>many-device</span> life.
          </h2>
        </div>

        <div className="feat-grid" style={styles.grid}>
          {cells.map((c, i) => (
            <div
              key={i}
              className="card"
              style={{
                ...styles.cell,
                gridColumn: c.span === 'wide' ? '1 / span 1' : 'auto',
                gridRow: c.span === 'wide' ? '1 / span 2' : 'auto',
              }}>
              <div style={styles.iconWrap}>{c.icon}</div>
              <div style={styles.cellTitle}>{c.title}</div>
              <p style={styles.cellBody}>{c.body}</p>
              {c.diagram}
            </div>
          ))}
        </div>
      </div>
      <style>{`
        @media (max-width: 1000px) {
          .feat-grid {
            grid-template-columns: 1fr 1fr !important;
            grid-auto-rows: auto !important;
          }
          .feat-grid > .card:first-child {
            grid-column: 1 / -1 !important;
            grid-row: auto !important;
          }
        }
        @media (max-width: 640px) {
          .feat-grid { grid-template-columns: 1fr !important; }
        }
      `}</style>
    </section>
  );
}
