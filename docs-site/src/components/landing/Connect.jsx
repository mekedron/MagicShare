// "Connect your devices" — animated pairing onboarding.
// Three devices light up one-by-one as they're added to your personal network.

const styles = {
  section: {paddingTop: 24, paddingBottom: 96},
  header: {textAlign: 'center', maxWidth: 760, margin: '0 auto 56px'},
  h2: {fontSize: 'clamp(36px, 5vw, 64px)', marginTop: 12},
  sub: {color: 'var(--ink-2)', marginTop: 18, fontSize: 16, lineHeight: 1.55},
  shell: {
    padding: 36,
    display: 'grid',
    gridTemplateColumns: '1fr 1.1fr',
    gap: 36,
    alignItems: 'center',
  },
  steps: {display: 'flex', flexDirection: 'column', gap: 18},
  step: {
    display: 'flex',
    gap: 14,
    alignItems: 'flex-start',
    padding: '14px 16px',
    border: '1px solid var(--line-soft)',
    borderRadius: 12,
    background: 'color-mix(in oklch, var(--bg-1) 70%, transparent)',
  },
  stepNum: {
    width: 28,
    height: 28,
    borderRadius: 999,
    flexShrink: 0,
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    border: '1px solid var(--line)',
    fontFamily: 'Geist Mono, monospace',
    fontSize: 12,
    color: 'var(--ink-2)',
    background: 'color-mix(in oklch, var(--bg-2) 60%, transparent)',
  },
  stepTitle: {color: 'var(--ink-0)', fontSize: 15, fontWeight: 500},
  stepBody: {color: 'var(--ink-2)', fontSize: 13.5, lineHeight: 1.55, marginTop: 4},
};

function PairingDiagram() {
  return (
    <div
      style={{
        position: 'relative',
        aspectRatio: '1 / 0.9',
        width: '100%',
        borderRadius: 16,
        border: '1px solid var(--line-soft)',
        background: 'color-mix(in oklch, var(--bg-2) 40%, transparent)',
        overflow: 'hidden',
      }}>
      <style>{`
        @keyframes net-ring {
          0%   { transform: scale(0.6); opacity: 0; }
          20%  { opacity: 0.6; }
          100% { transform: scale(2.2); opacity: 0; }
        }
        @keyframes dev-light-1 {
          0%,5%   { opacity: 0.35; }
          15%     { opacity: 1; }
          100%    { opacity: 1; }
        }
        @keyframes dev-light-2 {
          0%,30%  { opacity: 0.35; }
          42%     { opacity: 1; }
          100%    { opacity: 1; }
        }
        @keyframes dev-light-3 {
          0%,55%  { opacity: 0.35; }
          67%     { opacity: 1; }
          100%    { opacity: 1; }
        }
        @keyframes link-1 { 0%,8%{stroke-dashoffset:80;opacity:0} 18%{stroke-dashoffset:0;opacity:1} 100%{stroke-dashoffset:0;opacity:1} }
        @keyframes link-2 { 0%,33%{stroke-dashoffset:80;opacity:0} 45%{stroke-dashoffset:0;opacity:1} 100%{stroke-dashoffset:0;opacity:1} }
        @keyframes link-3 { 0%,58%{stroke-dashoffset:100;opacity:0} 70%{stroke-dashoffset:0;opacity:1} 100%{stroke-dashoffset:0;opacity:1} }
      `}</style>

      <span
        className="mono"
        style={{
          position: 'absolute',
          top: 14,
          left: 16,
          fontSize: 10,
          letterSpacing: '0.18em',
          color: 'var(--ink-3)',
        }}>
        YOUR DEVICES · 1 ACCOUNT
      </span>

      <svg viewBox="0 0 480 420" width="100%" height="100%">
        <defs>
          <radialGradient id="ms-hub-glow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="var(--spark)" stopOpacity="0.35" />
            <stop offset="60%" stopColor="var(--spark)" stopOpacity="0.08" />
            <stop offset="100%" stopColor="var(--spark)" stopOpacity="0" />
          </radialGradient>
        </defs>

        <circle cx="240" cy="220" r="120" fill="url(#ms-hub-glow)" />
        {[0, 1.6, 3.2].map((d, i) => (
          <circle
            key={i}
            cx="240"
            cy="220"
            r="40"
            fill="none"
            stroke="color-mix(in oklch, var(--spark) 40%, transparent)"
            strokeWidth="1.4"
            style={{
              transformOrigin: '240px 220px',
              transformBox: 'view-box',
              animation: `net-ring 4.8s ease-out ${d}s infinite`,
            }}
          />
        ))}

        <g transform="translate(220, 200)" fill="var(--spark)">
          <path
            d="M20 0 L23 14 L40 17 L23 20 L20 34 L17 20 L0 17 L17 14 Z"
            stroke="color-mix(in oklch, var(--spark) 60%, transparent)"
            strokeWidth="0.8"
          />
        </g>

        <line
          x1="240"
          y1="220"
          x2="100"
          y2="100"
          stroke="var(--spark)"
          strokeWidth="1.4"
          strokeDasharray="4 4"
          style={{animation: 'link-1 6s ease-in-out infinite'}}
        />
        <line
          x1="240"
          y1="220"
          x2="380"
          y2="120"
          stroke="var(--spark)"
          strokeWidth="1.4"
          strokeDasharray="4 4"
          style={{animation: 'link-2 6s ease-in-out infinite'}}
        />
        <line
          x1="240"
          y1="220"
          x2="380"
          y2="340"
          stroke="var(--spark)"
          strokeWidth="1.4"
          strokeDasharray="4 4"
          style={{animation: 'link-3 6s ease-in-out infinite'}}
        />

        <g transform="translate(58, 78)" style={{animation: 'dev-light-1 6s ease-in-out infinite'}}>
          <rect width="84" height="50" rx="6" fill="var(--device-fill)" stroke="var(--line)" />
          <rect x="5" y="5" width="74" height="40" rx="3" fill="var(--device-screen)" />
          <rect x="-10" y="50" width="104" height="3" rx="1.5" fill="var(--device-fill)" stroke="var(--line)" />
          <text
            x="42"
            y="76"
            textAnchor="middle"
            fill="var(--ink-2)"
            style={{font: "500 10px 'Geist Mono',monospace", letterSpacing: '0.14em'}}>
            MAC
          </text>
        </g>
        <g transform="translate(354, 90)" style={{animation: 'dev-light-2 6s ease-in-out infinite'}}>
          <rect width="36" height="60" rx="7" fill="var(--device-fill)" stroke="var(--line)" />
          <rect x="3" y="4" width="30" height="52" rx="4" fill="var(--device-screen)" />
          <text
            x="18"
            y="78"
            textAnchor="middle"
            fill="var(--ink-2)"
            style={{font: "500 10px 'Geist Mono',monospace", letterSpacing: '0.14em'}}>
            PIXEL
          </text>
        </g>
        <g transform="translate(338, 308)" style={{animation: 'dev-light-3 6s ease-in-out infinite'}}>
          <rect width="72" height="56" rx="6" fill="var(--device-fill)" stroke="var(--line)" />
          <rect x="4" y="4" width="64" height="48" rx="3" fill="var(--device-screen)" />
          <text
            x="36"
            y="80"
            textAnchor="middle"
            fill="var(--ink-2)"
            style={{font: "500 10px 'Geist Mono',monospace", letterSpacing: '0.14em'}}>
            iPAD
          </text>
        </g>
      </svg>
    </div>
  );
}

export default function Connect() {
  return (
    <section className="section" id="connect" style={styles.section}>
      <div className="wrap">
        <div style={styles.header}>
          <span className="eyebrow">Setup, once</span>
          <h2 className="display" style={styles.h2}>
            Your devices,{' '}
            <span className="upright" style={{color: 'var(--spark)'}}>introduced</span>.
          </h2>
          <p style={styles.sub}>
            Install MagicShare on each device and tap “add to my devices.” No
            email, no phone number — just an anonymous account that ties your
            devices together so they recognize each other later.
          </p>
        </div>

        <div className="card" style={styles.shell}>
          <div className="connect-anim">
            <PairingDiagram />
          </div>
          <div style={styles.steps}>
            <div style={styles.step}>
              <span style={styles.stepNum}>1</span>
              <div>
                <div style={styles.stepTitle}>Install MagicShare on a device</div>
                <div style={styles.stepBody}>
                  Mac, Windows, Linux, iOS, or Android. Free, open source, takes a minute.
                </div>
              </div>
            </div>
            <div style={styles.step}>
              <span style={styles.stepNum}>2</span>
              <div>
                <div style={styles.stepTitle}>Sign in anonymously</div>
                <div style={styles.stepBody}>
                  No email, no password — just a private account that exists to
                  identify your devices to each other.
                </div>
              </div>
            </div>
            <div style={styles.step}>
              <span style={styles.stepNum}>3</span>
              <div>
                <div style={styles.stepTitle}>Repeat on every device you own</div>
                <div style={styles.stepBody}>
                  They’ll recognize each other from then on. Rename, remove, or
                  add a new one any time.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <style>{`
        @media (max-width: 900px) {
          #connect .card {
            grid-template-columns: 1fr !important;
            padding: 24px !important;
          }
          .connect-anim { max-width: 420px; margin: 0 auto; }
        }
      `}</style>
    </section>
  );
}
