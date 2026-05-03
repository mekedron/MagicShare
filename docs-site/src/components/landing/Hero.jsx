// Hero — the signature animation.
//
// Source = Mac (left). Targets = iPad (center, slightly back) and Pixel (right).
// Sparks: file flies up to cloud, fans to BOTH targets via cloud (heads-up
// nudge), then P2P beams stream the actual file to BOTH targets directly.
//
// The Docusaurus navbar provides the page-level navigation (logo, anchor
// links, donate, GitHub, get the app). This component renders the hero
// content only — no in-section <nav>.

import {DownloadIcon, ArrowIcon, LockIcon, WifiIcon, GithubIcon} from './Icons';

const styles = {
  section: {
    position: 'relative',
    paddingTop: 'calc(env(safe-area-inset-top) + 24px)',
    paddingBottom: 96,
    overflow: 'hidden',
  },
  hero: {
    display: 'grid',
    gridTemplateColumns: '1.05fr 1fr',
    gap: 56,
    alignItems: 'center',
    paddingTop: 64,
  },
  h1: {fontSize: 'clamp(48px, 7vw, 92px)', margin: 0},
  shimmer: {
    background:
      'linear-gradient(90deg, var(--spark), var(--aura), var(--beam), var(--spark))',
    backgroundSize: '300% 100%',
    WebkitBackgroundClip: 'text',
    backgroundClip: 'text',
    color: 'transparent',
    animation: 'hero-shimmer 8s linear infinite',
  },
  sub: {
    color: 'var(--ink-2)',
    fontSize: 'clamp(15px, 1.4vw, 18px)',
    maxWidth: 520,
    marginTop: 28,
    lineHeight: 1.55,
  },
  ctas: {display: 'flex', gap: 12, marginTop: 36, flexWrap: 'wrap'},
  microBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 8,
    padding: '6px 12px',
    border: '1px solid var(--line)',
    borderRadius: 999,
    fontSize: 12,
    color: 'var(--ink-2)',
    background: 'color-mix(in oklch, var(--bg-2) 70%, transparent)',
    backdropFilter: 'blur(6px)',
    whiteSpace: 'nowrap',
    maxWidth: '100%',
  },
  pulse: {
    width: 6,
    height: 6,
    borderRadius: 999,
    background: 'var(--spark)',
    boxShadow: '0 0 12px var(--spark)',
    animation: 'pulse-soft 2s ease-in-out infinite',
  },
  trust: {
    display: 'flex',
    gap: 22,
    marginTop: 32,
    flexWrap: 'wrap',
    fontSize: 13,
    color: 'var(--ink-2)',
  },
  trustItem: {display: 'inline-flex', alignItems: 'center', gap: 8},
};

function HeroAnimation() {
  return (
    <div style={{position: 'relative', aspectRatio: '1/1', width: '100%'}}>
      <style>{`
        @keyframes hero-shimmer {
          0% { background-position: 0% 50%; }
          100% { background-position: 300% 50%; }
        }
        @keyframes orbit-spin { to { transform: rotate(360deg); } }
        @keyframes float-y {
          0%,100% { transform: translateY(0); }
          50%     { transform: translateY(-8px); }
        }
        @keyframes ring-pulse {
          0%   { transform: scale(0.4); opacity: 0.7; }
          100% { transform: scale(2.4); opacity: 0; }
        }
        @keyframes spark-up {
          0%,3%   { offset-distance: 0%;   opacity: 0; }
          8%      { opacity: 1; }
          25%     { offset-distance: 100%; opacity: 1; }
          30%,100%{ offset-distance: 100%; opacity: 0; }
        }
        @keyframes spark-down-a {
          0%,25%   { offset-distance: 0%;   opacity: 0; }
          30%      { opacity: 1; }
          45%      { offset-distance: 100%; opacity: 1; }
          50%,100% { opacity: 0; }
        }
        @keyframes spark-down-b {
          0%,27%   { offset-distance: 0%;   opacity: 0; }
          32%      { opacity: 1; }
          47%      { offset-distance: 100%; opacity: 1; }
          52%,100% { opacity: 0; }
        }
        @keyframes p2p-flow {
          0%,48%  { opacity: 0; }
          52%     { opacity: 1; }
          88%     { opacity: 1; }
          92%,100%{ opacity: 0; }
        }
        @keyframes p2p-pkt {
          0%,48%   { offset-distance: 0%;   opacity: 0; }
          52%      { opacity: 1; }
          85%      { offset-distance: 100%; opacity: 1; }
          90%,100% { opacity: 0; }
        }
        @keyframes notif-in {
          0%,30%  { opacity: 0; transform: translate(0, 6px) scale(0.94); }
          38%     { opacity: 1; transform: translate(0, 0)   scale(1); }
          62%     { opacity: 1; transform: translate(0, 0)   scale(1); }
          70%,100%{ opacity: 0; transform: translate(0, -4px) scale(0.96); }
        }
        @keyframes file-glow {
          0%,4%   { opacity: 0.2; transform: scale(0.9); }
          12%     { opacity: 1;   transform: scale(1.05); }
          22%     { opacity: 0.6; transform: scale(1); }
          100%    { opacity: 0.4; }
        }
        @keyframes file-received {
          0%,70%   { opacity: 0; transform: scale(0.6); }
          78%      { opacity: 1; transform: scale(1.08); }
          85%,100% { opacity: 1; transform: scale(1); }
        }
        @keyframes badge-flash {
          0%,30% { box-shadow: 0 0 0 0 transparent; }
          38%    { box-shadow: 0 0 0 14px transparent; border-color: color-mix(in oklch, var(--spark) 60%, transparent); }
          70%    { box-shadow: 0 0 0 0 transparent; }
          100%   { box-shadow: 0 0 0 0 transparent; }
        }
      `}</style>

      <svg viewBox="0 0 600 600" width="100%" height="100%" style={{display: 'block'}}>
        <defs>
          <path id="ms-p-up" fill="none" d="M 150 430 C 200 320, 260 250, 300 180" />
          <path id="ms-p-down-pixel" fill="none" d="M 300 180 C 360 240, 420 320, 470 410" />
          <path id="ms-p-down-ipad" fill="none" d="M 300 180 C 300 220, 300 280, 300 330" />
          <path id="ms-p-p2p-pixel" fill="none" d="M 175 470 C 280 540, 380 540, 460 460" />
          <path id="ms-p-p2p-ipad" fill="none" d="M 200 450 C 240 410, 270 380, 295 360" />

          <linearGradient id="ms-beam" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="var(--beam)" stopOpacity="0" />
            <stop offset="50%" stopColor="var(--beam)" stopOpacity="0.9" />
            <stop offset="100%" stopColor="var(--beam)" stopOpacity="0" />
          </linearGradient>
          <radialGradient id="ms-cloud-glow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="var(--aura)" stopOpacity="0.55" />
            <stop offset="60%" stopColor="var(--aura)" stopOpacity="0.15" />
            <stop offset="100%" stopColor="var(--aura)" stopOpacity="0" />
          </radialGradient>
        </defs>

        <g
          style={{
            transformOrigin: 'center',
            transformBox: 'view-box',
            animation: 'orbit-spin 80s linear infinite',
          }}>
          <circle cx="300" cy="300" r="270" fill="none" stroke="var(--line-soft)" strokeDasharray="2 8" />
          <circle cx="300" cy="300" r="220" fill="none" stroke="var(--line-soft)" strokeDasharray="2 10" opacity="0.6" />
        </g>

        <use href="#ms-p-up" stroke="var(--ink-3)" strokeWidth="1.2" strokeDasharray="2 6" strokeOpacity="0.55" fill="none" />
        <use href="#ms-p-down-pixel" stroke="var(--ink-3)" strokeWidth="1.2" strokeDasharray="2 6" strokeOpacity="0.55" fill="none" />
        <use href="#ms-p-down-ipad" stroke="var(--ink-3)" strokeWidth="1.2" strokeDasharray="2 6" strokeOpacity="0.55" fill="none" />
        <use href="#ms-p-p2p-pixel" stroke="var(--beam)" strokeOpacity="0.45" strokeWidth="1.2" strokeDasharray="3 5" fill="none" />
        <use href="#ms-p-p2p-ipad" stroke="var(--beam)" strokeOpacity="0.45" strokeWidth="1.2" strokeDasharray="3 5" fill="none" />

        <g style={{animation: 'p2p-flow 8s ease-in-out infinite'}}>
          <use
            href="#ms-p-p2p-pixel"
            stroke="url(#ms-beam)"
            strokeWidth="2.5"
            fill="none"
            strokeLinecap="round"
            strokeDasharray="6 6"
            style={{animation: 'dash-flow 4s linear infinite'}}
          />
          <use
            href="#ms-p-p2p-ipad"
            stroke="url(#ms-beam)"
            strokeWidth="2.5"
            fill="none"
            strokeLinecap="round"
            strokeDasharray="6 6"
            style={{animation: 'dash-flow 4s linear infinite'}}
          />
        </g>

        <circle cx="300" cy="180" r="80" fill="url(#ms-cloud-glow)" />

        <g
          transform="translate(266, 156)"
          stroke="var(--aura)"
          fill="none"
          strokeWidth="1.6"
          strokeLinecap="round"
          strokeLinejoin="round">
          <path
            d="M14 36 H50 a8 8 0 0 0 1.4 -15.88 A12 12 0 0 0 12 24 a8 8 0 0 0 2 12 Z"
            fill="color-mix(in oklch, var(--aura) 14%, var(--bg-0))"
          />
          {/* Checkmark sits inside the cloud body (cloud spans roughly
              y=12..36; this places the tick around the vertical centre). */}
          <path d="M22 20 l5 5 l10 -10" stroke="var(--spark)" strokeWidth="2" />
        </g>
        <text
          x="300"
          y="248"
          textAnchor="middle"
          fill="var(--ink-2)"
          style={{font: "500 11px 'Geist Mono',monospace", letterSpacing: '0.18em'}}>
          HEADS-UP
        </text>

        {/* iPad — center, behind */}
        <g transform="translate(252, 320)">
          <g style={{animation: 'float-y 7s ease-in-out 1s infinite'}}>
            <rect x="0" y="0" width="96" height="74" rx="8" fill="var(--device-fill-2)" stroke="var(--line)" />
            <rect x="5" y="5" width="86" height="64" rx="4" fill="var(--device-screen-2)" />
            <g transform="translate(48, 22)">
              <g style={{animation: 'notif-in 8s ease-in-out infinite'}}>
                <rect
                  x="-32"
                  y="0"
                  width="64"
                  height="20"
                  rx="4"
                  fill="color-mix(in oklch, var(--aura) 28%, var(--bg-1))"
                  stroke="color-mix(in oklch, var(--aura) 70%, transparent)"
                />
                <circle cx="-23" cy="10" r="3" fill="var(--spark)" />
                <rect x="-16" y="5" width="30" height="2" rx="1" fill="color-mix(in oklch, var(--ink-1) 90%, transparent)" />
                <rect x="-16" y="11" width="22" height="2" rx="1" fill="color-mix(in oklch, var(--ink-2) 70%, transparent)" />
              </g>
              <g transform="translate(0, -2)">
                <g
                  style={{
                    animation: 'file-received 8s ease-in-out infinite',
                    transformOrigin: '-16px 12px',
                    transformBox: 'fill-box',
                  }}>
                  <rect x="-14" y="4" width="14" height="16" rx="2" fill="none" stroke="var(--spark)" strokeWidth="1.4" />
                  <path d="M-6 4 L0 10" stroke="var(--spark)" strokeWidth="1.4" />
                  <rect x="-12" y="10" width="10" height="1.5" rx="0.5" fill="var(--spark)" opacity="0.7" />
                  <rect x="-12" y="14" width="7" height="1.5" rx="0.5" fill="var(--spark)" opacity="0.45" />
                </g>
              </g>
            </g>
            <text
              x="48"
              y="92"
              textAnchor="middle"
              fill="var(--ink-2)"
              style={{font: "500 10px 'Geist Mono',monospace", letterSpacing: '0.16em'}}>
              iPAD
            </text>
          </g>
        </g>

        {/* Mac — lower-left, in front */}
        <g transform="translate(85, 410)">
          <g style={{animation: 'float-y 6s ease-in-out infinite'}}>
            <rect x="0" y="0" width="120" height="70" rx="6" fill="var(--device-fill)" stroke="var(--line)" />
            <rect x="6" y="6" width="108" height="54" rx="3" fill="var(--device-screen)" />
            {/* CSS `transform: scale(...)` from `file-glow` would override
                an SVG `transform="translate(...)"` on the same element and
                snap the icon to (0,0). Wrap with an outer translate group
                so positioning survives the animated scale. */}
            <g transform="translate(43, 17)">
              <g
                style={{
                  animation: 'file-glow 8s ease-in-out infinite',
                  transformOrigin: '17px 17px',
                  transformBox: 'fill-box',
                }}>
                <rect x="0" y="0" width="34" height="34" rx="3" fill="none" stroke="var(--spark)" strokeWidth="1.6" />
                <path d="M22 0 L34 12" stroke="var(--spark)" strokeWidth="1.6" fill="none" />
                <rect x="6" y="14" width="22" height="2" rx="1" fill="var(--spark)" opacity="0.7" />
                <rect x="6" y="20" width="16" height="2" rx="1" fill="var(--spark)" opacity="0.45" />
              </g>
            </g>
            <rect x="-14" y="70" width="148" height="5" rx="2.5" fill="var(--device-fill)" stroke="var(--line)" />
            <text
              x="60"
              y="92"
              textAnchor="middle"
              fill="var(--ink-2)"
              style={{font: "500 10px 'Geist Mono',monospace", letterSpacing: '0.16em'}}>
              MAC · SOURCE
            </text>
          </g>
        </g>

        {/* Pixel — lower-right, in front */}
        <g transform="translate(440, 380)">
          <g style={{animation: 'float-y 5s ease-in-out 0.4s infinite'}}>
            <rect x="0" y="0" width="60" height="100" rx="10" fill="var(--device-fill-3)" stroke="var(--line)" />
            <rect x="4" y="6" width="52" height="88" rx="6" fill="var(--device-screen-3)" />
            <circle cx="30" cy="11" r="1.6" fill="var(--ink-3)" />
            <g transform="translate(30, 28)">
              <g style={{animation: 'notif-in 8s ease-in-out infinite'}}>
                <rect
                  x="-22"
                  y="0"
                  width="44"
                  height="22"
                  rx="4"
                  fill="color-mix(in oklch, var(--aura) 28%, var(--bg-1))"
                  stroke="color-mix(in oklch, var(--aura) 70%, transparent)"
                />
                <circle cx="-15" cy="11" r="3" fill="var(--spark)" />
                <rect x="-9" y="5" width="20" height="2" rx="1" fill="color-mix(in oklch, var(--ink-1) 90%, transparent)" />
                <rect x="-9" y="10" width="14" height="2" rx="1" fill="color-mix(in oklch, var(--ink-2) 70%, transparent)" />
                <rect x="-9" y="14" width="16" height="2" rx="1" fill="color-mix(in oklch, var(--ink-2) 70%, transparent)" />
              </g>
              <g transform="translate(-10, 32)">
                <g
                  style={{
                    animation: 'file-received 8s ease-in-out infinite',
                    transformOrigin: 'center',
                    transformBox: 'fill-box',
                  }}>
                  <rect x="0" y="0" width="20" height="22" rx="2.5" fill="none" stroke="var(--spark)" strokeWidth="1.4" />
                  <path d="M12 0 L20 8" stroke="var(--spark)" strokeWidth="1.4" />
                  <rect x="3" y="11" width="14" height="1.6" rx="0.5" fill="var(--spark)" opacity="0.7" />
                  <rect x="3" y="15" width="10" height="1.6" rx="0.5" fill="var(--spark)" opacity="0.45" />
                </g>
              </g>
            </g>
            <text
              x="30"
              y="120"
              textAnchor="middle"
              fill="var(--ink-2)"
              style={{font: "500 10px 'Geist Mono',monospace", letterSpacing: '0.16em'}}>
              PIXEL
            </text>
          </g>
        </g>

        {/* traveling sparks */}
        <circle
          r="5"
          fill="var(--spark)"
          style={{
            offsetPath: "path('M 150 430 C 200 320, 260 250, 300 180')",
            filter: 'drop-shadow(0 0 8px var(--spark))',
            animation: 'spark-up 8s ease-in-out infinite',
          }}
        />
        <circle
          r="4"
          fill="var(--aura)"
          style={{
            offsetPath: "path('M 300 180 C 300 220, 300 280, 300 330')",
            filter: 'drop-shadow(0 0 8px var(--aura))',
            animation: 'spark-down-a 8s ease-in-out infinite',
          }}
        />
        <circle
          r="4"
          fill="var(--aura)"
          style={{
            offsetPath: "path('M 300 180 C 360 240, 420 320, 470 410')",
            filter: 'drop-shadow(0 0 8px var(--aura))',
            animation: 'spark-down-b 8s ease-in-out infinite',
          }}
        />
        <circle
          r="3.5"
          fill="var(--beam)"
          style={{
            offsetPath: "path('M 175 470 C 280 540, 380 540, 460 460')",
            filter: 'drop-shadow(0 0 6px var(--beam))',
            animation: 'p2p-pkt 8s ease-in-out infinite',
          }}
        />
        <circle
          r="3.5"
          fill="var(--beam)"
          style={{
            offsetPath: "path('M 200 450 C 240 410, 270 380, 295 360')",
            filter: 'drop-shadow(0 0 6px var(--beam))',
            animation: 'p2p-pkt 8s ease-in-out 0.2s infinite',
          }}
        />

        <g transform="translate(300, 270)">
          <rect
            x="-58"
            y="-14"
            width="116"
            height="28"
            rx="14"
            fill="color-mix(in oklch, var(--bg-2) 70%, transparent)"
            stroke="var(--line)"
            style={{animation: 'badge-flash 8s ease-in-out infinite'}}
          />
          <text
            textAnchor="middle"
            y="4"
            fill="var(--ink-1)"
            style={{font: "500 11px 'Geist Mono',monospace", letterSpacing: '0.14em'}}>
            poof.
          </text>
        </g>
      </svg>
    </div>
  );
}

export default function Hero() {
  return (
    <header style={styles.section}>
      <div className="wrap">
        <div style={styles.hero} className="hero-grid">
          <div>
            <span style={styles.microBadge}>
              <span style={styles.pulse} />
              Cross-platform · open · free
            </span>

            <h1 className="display" style={{...styles.h1, marginTop: 22}}>
              Send a file <br />
              to any device <span className="upright" style={styles.shimmer}>you own</span>.
              <br />
              <span style={{opacity: 0.85}}>Like magic.</span>
            </h1>

            <p style={styles.sub}>
              Drop a file or paste a link on one device. Pick another. It’s
              there — even across Mac, Windows, Linux, iOS, and Android. No
              emails to yourself, no QR codes, no “open the app first.”
            </p>

            <div style={styles.ctas}>
              <a href="#download" className="btn btn-primary">
                <DownloadIcon /> Download for free
              </a>
              <a href="#how" className="btn btn-ghost">
                See how it works <ArrowIcon />
              </a>
            </div>

            <div style={styles.trust}>
              <span style={styles.trustItem}>
                <LockIcon /> End-to-end encrypted
              </span>
              <span style={styles.trustItem}>
                <WifiIcon /> Direct device-to-device
              </span>
              <span style={styles.trustItem}>
                <GithubIcon /> Open source
              </span>
            </div>
          </div>

          <div className="hero-anim">
            <HeroAnimation />
          </div>
        </div>
      </div>

      <style>{`
        @media (max-width: 900px) {
          .hero-grid { grid-template-columns: 1fr !important; gap: 32px !important; padding-top: 16px !important; }
          /* Headline first, animation second — flipping the order on mobile
             made the page open with a wall of empty space above an unlabelled
             diagram, hiding what the product even is until you scrolled. */
          .hero-anim { max-width: 420px; margin: 0 auto; width: 100%; }
        }
      `}</style>
    </header>
  );
}
