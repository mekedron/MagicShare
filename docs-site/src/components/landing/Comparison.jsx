// The pain users actually have today, animated.
//
// Three "old way" mini-scenes cycle on the left.
// The "MagicShare way" plays on the right — paste/drop, pick, done.

import {XIcon, CheckIcon, BellIcon} from './Icons';

const styles = {
  section: {paddingTop: 24, paddingBottom: 96},
  header: {textAlign: 'center', maxWidth: 760, margin: '0 auto 56px'},
  h2: {fontSize: 'clamp(36px, 5vw, 64px)', marginTop: 12, lineHeight: 1.05},
  sub: {color: 'var(--ink-2)', marginTop: 32, fontSize: 16, lineHeight: 1.55},
  grid: {display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, alignItems: 'stretch'},
  col: {padding: 32, minHeight: 520, display: 'flex', flexDirection: 'column', gap: 16},
  colHead: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    color: 'var(--ink-0)',
    fontWeight: 500,
    fontSize: 18,
  },
  scene: {
    position: 'relative',
    minHeight: 220,
    borderRadius: 14,
    border: '1px solid var(--line-soft)',
    background: 'color-mix(in oklch, var(--bg-2) 50%, transparent)',
    padding: 18,
    overflow: 'hidden',
  },
  sceneTag: {
    fontFamily: 'Geist Mono, monospace',
    fontSize: 10,
    letterSpacing: '0.18em',
    color: 'var(--ink-3)',
  },
  sceneCaption: {color: 'var(--ink-2)', fontSize: 13.5, lineHeight: 1.5, marginTop: 2},
};

function PainScene() {
  return (
    <div style={styles.scene}>
      <div style={styles.sceneTag}>SCENE · CROSS-PLATFORM CLIPBOARD</div>
      <style>{`
        @keyframes copy-blink {
          0%,12% { background: color-mix(in oklch, var(--bg-1) 70%, transparent); border-color: var(--line); }
          16%    { background: color-mix(in oklch, var(--spark) 22%, var(--bg-1)); border-color: color-mix(in oklch, var(--spark) 60%, transparent); }
          50%,100% { background: color-mix(in oklch, var(--bg-1) 70%, transparent); border-color: var(--line); }
        }
        @keyframes paste-fail {
          0%,55%  { transform: translateY(0) rotate(0); border-color: color-mix(in oklch, var(--ink-3) 40%, transparent); }
          60%     { transform: translateY(-2px) rotate(-1deg); border-color: color-mix(in oklch, var(--spark) 60%, transparent); }
          70%     { transform: translateX(-3px) rotate(0deg); border-color: color-mix(in oklch, oklch(70% 0.18 30) 70%, transparent); }
          75%     { transform: translateX(3px); }
          80%     { transform: translateX(-2px); }
          85%,100%{ transform: translateX(0) rotate(0); border-color: color-mix(in oklch, oklch(70% 0.18 30) 60%, transparent); }
        }
        @keyframes empty-toast {
          0%,70% { opacity: 0; transform: translateY(6px); }
          80%    { opacity: 1; transform: translateY(0); }
          100%   { opacity: 1; }
        }
        @keyframes label-fade-1 { 0%,12%{opacity:1} 22%,100%{opacity:.4} }
        @keyframes label-fade-2 { 0%,12%{opacity:.4} 22%,55%{opacity:1} 65%,100%{opacity:.4} }
        @keyframes label-fade-3 { 0%,55%{opacity:.4} 65%,100%{opacity:1} }
      `}</style>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr auto 1fr',
          gap: 14,
          alignItems: 'center',
          marginTop: 20,
        }}>
        <div
          style={{
            padding: 10,
            borderRadius: 10,
            border: '1px solid var(--line)',
            background: 'color-mix(in oklch, var(--bg-1) 70%, transparent)',
            animation: 'copy-blink 6s ease-in-out infinite',
          }}>
          <div
            className="mono"
            style={{
              fontSize: 9,
              color: 'var(--ink-3)',
              letterSpacing: '0.14em',
              marginBottom: 6,
            }}>
            MAC · COPY
          </div>
          <div style={{fontSize: 12, color: 'var(--ink-1)', lineHeight: 1.4, wordBreak: 'break-all'}}>
            <span style={{color: 'var(--spark)'}}>https://</span>example.com/article/very-long-url-with-tracking
          </div>
        </div>

        <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6}}>
          <span
            className="mono"
            style={{fontSize: 9, color: 'var(--ink-3)', letterSpacing: '0.14em'}}>
            →
          </span>
          <span style={{fontSize: 16}}>·</span>
        </div>

        <div
          style={{
            padding: 10,
            borderRadius: 10,
            border: '1px dashed var(--line)',
            background: 'color-mix(in oklch, var(--bg-1) 70%, transparent)',
            minHeight: 64,
            animation: 'paste-fail 6s ease-in-out infinite',
            position: 'relative',
          }}>
          <div
            className="mono"
            style={{fontSize: 9, color: 'var(--ink-3)', letterSpacing: '0.14em', marginBottom: 6}}>
            PIXEL · PASTE
          </div>
          <div style={{fontSize: 11, color: 'var(--ink-3)', fontStyle: 'italic'}}>nothing here</div>
          <div
            className="mono"
            style={{
              position: 'absolute',
              inset: 'auto 6px 6px auto',
              fontSize: 9,
              padding: '3px 6px',
              borderRadius: 4,
              background: 'color-mix(in oklch, oklch(60% 0.18 30) 22%, var(--bg-1))',
              color: 'oklch(70% 0.18 30)',
              border: '1px solid color-mix(in oklch, oklch(70% 0.18 30) 50%, transparent)',
              animation: 'empty-toast 6s ease-in-out infinite',
            }}>
            cross-OS clipboard not synced
          </div>
        </div>
      </div>

      <div style={{marginTop: 18, display: 'flex', flexDirection: 'column', gap: 4}}>
        <div style={{...styles.sceneCaption, animation: 'label-fade-1 6s linear infinite'}}>
          1. Copy a link on your Mac.
        </div>
        <div style={{...styles.sceneCaption, animation: 'label-fade-2 6s linear infinite'}}>
          2. Pick up your Android phone, try to paste.
        </div>
        <div
          style={{
            ...styles.sceneCaption,
            animation: 'label-fade-3 6s linear infinite',
            color: 'oklch(70% 0.16 30)',
          }}>
          3. Nothing. Email yourself? Type the URL by hand?
        </div>
      </div>
    </div>
  );
}

function WalledGardenStrip() {
  const items = [
    {name: 'AirDrop', desc: 'Apple only'},
    {name: 'Quick Share', desc: 'Android / Windows'},
    {name: 'Nearby Share', desc: 'won’t see your iPad'},
  ];
  return (
    <div style={{display: 'flex', flexDirection: 'column', gap: 8}}>
      {items.map((it) => (
        <div
          key={it.name}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            padding: '10px 14px',
            border: '1px solid var(--line-soft)',
            borderRadius: 10,
            background: 'color-mix(in oklch, var(--bg-1) 60%, transparent)',
            fontSize: 13,
          }}>
          <span style={{color: 'oklch(70% 0.16 30)'}}>
            <XIcon />
          </span>
          <strong style={{color: 'var(--ink-1)', fontWeight: 500}}>{it.name}</strong>
          <span
            className="mono"
            style={{
              color: 'var(--ink-3)',
              fontSize: 11,
              letterSpacing: '0.1em',
              marginLeft: 'auto',
            }}>
            {it.desc}
          </span>
        </div>
      ))}
    </div>
  );
}

function OldWayCol() {
  return (
    <div className="card" style={styles.col}>
      <div style={styles.colHead}>
        <span style={{width: 10, height: 10, borderRadius: 999, background: 'var(--ink-3)'}} />
        How people do this today
      </div>
      <p style={{color: 'var(--ink-2)', fontSize: 14, margin: 0, lineHeight: 1.55}}>
        If you mix platforms — Mac + Android, Windows + iPhone, Linux + anything —
        the small stuff falls apart constantly.
      </p>

      <PainScene />

      <div
        className="mono"
        style={{
          fontSize: 10,
          letterSpacing: '0.18em',
          color: 'var(--ink-3)',
          marginTop: 6,
        }}>
        WALLED GARDENS
      </div>
      <WalledGardenStrip />

      <div
        style={{
          marginTop: 'auto',
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '10px 14px',
          border: '1px dashed var(--line)',
          borderRadius: 10,
          fontSize: 13,
          color: 'var(--ink-2)',
        }}>
        <XIcon /> So you email yourself. Or DM yourself. Or type a URL by hand.
      </div>
    </div>
  );
}

function MagicScene() {
  return (
    <div style={styles.scene}>
      <div style={styles.sceneTag}>SCENE · ANY DEVICE → ANY DEVICE</div>
      <style>{`
        @keyframes ms-paste {
          0%,15% { box-shadow: 0 0 0 0 color-mix(in oklch, var(--spark) 0%, transparent); border-color: var(--line); }
          22%    { box-shadow: 0 0 0 4px color-mix(in oklch, var(--spark) 30%, transparent); border-color: color-mix(in oklch, var(--spark) 70%, transparent); }
          40%,100% { box-shadow: 0 0 0 0 transparent; border-color: var(--line); }
        }
        @keyframes ms-pick-1 {
          0%,32% { background: color-mix(in oklch, var(--bg-1) 70%, transparent); border-color: var(--line-soft); color: var(--ink-2); }
          40%    { background: color-mix(in oklch, var(--aura) 22%, var(--bg-1)); border-color: color-mix(in oklch, var(--aura) 70%, transparent); color: var(--ink-0); }
          100%   { background: color-mix(in oklch, var(--aura) 18%, var(--bg-1)); border-color: color-mix(in oklch, var(--aura) 60%, transparent); color: var(--ink-0); }
        }
        @keyframes ms-link-pop {
          0%,55%  { opacity: 0; transform: translateY(6px) scale(0.96); }
          65%     { opacity: 1; transform: translateY(0) scale(1); }
          85%,100%{ opacity: 1; }
        }
        @keyframes ms-browser-open {
          0%,68% { opacity: 0; transform: translateY(8px); }
          80%    { opacity: 1; transform: translateY(0); }
          100%   { opacity: 1; }
        }
      `}</style>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr auto 1fr',
          gap: 14,
          alignItems: 'center',
          marginTop: 20,
        }}>
        <div
          style={{
            padding: 12,
            borderRadius: 10,
            border: '1px solid var(--line)',
            background: 'color-mix(in oklch, var(--bg-1) 70%, transparent)',
            animation: 'ms-paste 6s ease-in-out infinite',
          }}>
          <div
            className="mono"
            style={{fontSize: 9, color: 'var(--ink-3)', letterSpacing: '0.14em', marginBottom: 6}}>
            MAC · PASTE
          </div>
          <div style={{fontSize: 12, color: 'var(--ink-1)', lineHeight: 1.4, wordBreak: 'break-all'}}>
            <span style={{color: 'var(--spark)'}}>https://</span>example.com/article
          </div>
          <div style={{display: 'flex', gap: 6, marginTop: 10, flexWrap: 'wrap'}}>
            <span
              style={{
                padding: '4px 8px',
                borderRadius: 999,
                fontSize: 10,
                border: '1px solid var(--line-soft)',
                animation: 'ms-pick-1 6s ease-in-out infinite',
              }}>
              Pixel
            </span>
            <span
              style={{
                padding: '4px 8px',
                borderRadius: 999,
                fontSize: 10,
                border: '1px solid var(--line-soft)',
                color: 'var(--ink-2)',
              }}>
              iPad
            </span>
            <span
              style={{
                padding: '4px 8px',
                borderRadius: 999,
                fontSize: 10,
                border: '1px solid var(--line-soft)',
                color: 'var(--ink-2)',
              }}>
              Win PC
            </span>
          </div>
        </div>

        <span
          className="mono"
          style={{fontSize: 9, color: 'var(--ink-3)', letterSpacing: '0.14em'}}>
          →
        </span>

        <div
          style={{
            padding: 10,
            borderRadius: 10,
            border: '1px solid var(--line)',
            background: 'color-mix(in oklch, var(--bg-1) 70%, transparent)',
            minHeight: 92,
            position: 'relative',
          }}>
          <div
            className="mono"
            style={{fontSize: 9, color: 'var(--ink-3)', letterSpacing: '0.14em', marginBottom: 6}}>
            PIXEL
          </div>
          <div
            style={{
              padding: '6px 8px',
              borderRadius: 6,
              background: 'color-mix(in oklch, var(--aura) 26%, var(--bg-1))',
              border: '1px solid color-mix(in oklch, var(--aura) 60%, transparent)',
              fontSize: 10,
              color: 'var(--ink-1)',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              animation: 'ms-link-pop 6s ease-in-out infinite',
            }}>
            <BellIcon size={11} /> Open link from Mac
          </div>
          <div
            style={{
              marginTop: 8,
              padding: '5px 8px',
              borderRadius: 6,
              background: 'color-mix(in oklch, var(--bg-2) 70%, transparent)',
              border: '1px solid var(--line-soft)',
              fontSize: 10,
              color: 'var(--ink-1)',
              display: 'flex',
              alignItems: 'center',
              gap: 5,
              animation: 'ms-browser-open 6s ease-in-out infinite',
            }}>
            <span
              style={{
                width: 6,
                height: 6,
                borderRadius: 999,
                background: 'oklch(72% 0.18 150)',
              }}
            />
            example.com — open
          </div>
        </div>
      </div>

      <div style={{marginTop: 16, ...styles.sceneCaption}}>
        Same for files. Same for photos. Same flow on every platform.
      </div>
    </div>
  );
}

function NewWayCol() {
  return (
    <div
      className="card"
      style={{
        ...styles.col,
        background:
          'radial-gradient(120% 80% at 100% 0%, color-mix(in oklch, var(--aura) 15%, transparent), transparent 50%), linear-gradient(180deg, var(--bg-1), var(--bg-0))',
        borderColor: 'color-mix(in oklch, var(--aura) 40%, var(--line))',
      }}>
      <div style={styles.colHead}>
        <span
          style={{
            width: 10,
            height: 10,
            borderRadius: 999,
            background: 'var(--spark)',
            boxShadow: '0 0 12px var(--spark)',
          }}
        />
        With MagicShare
      </div>
      <p style={{color: 'var(--ink-1)', fontSize: 14, margin: 0, lineHeight: 1.55}}>
        One app on every device. Drop a file. Or paste a link. Pick where it
        goes. That’s the whole flow.
      </p>

      <MagicScene />

      <div style={{display: 'flex', flexDirection: 'column', gap: 8, marginTop: 4}}>
        {[
          ['Mac → Android', 'links, files, photos'],
          ['Windows → iPhone', 'no Apple ID needed'],
          ['Linux → anywhere', 'the rest of the world remembers Linux'],
        ].map(([k, v]) => (
          <div
            key={k}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '10px 14px',
              border: '1px solid color-mix(in oklch, var(--aura) 30%, var(--line-soft))',
              borderRadius: 10,
              background: 'color-mix(in oklch, var(--aura) 8%, var(--bg-1))',
              fontSize: 13,
              color: 'var(--ink-0)',
            }}>
            <CheckIcon />
            <strong style={{fontWeight: 500}}>{k}</strong>
            <span
              className="mono"
              style={{
                color: 'var(--ink-2)',
                fontSize: 11,
                letterSpacing: '0.1em',
                marginLeft: 'auto',
              }}>
              {v}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function Comparison() {
  return (
    <section className="section" id="problem" style={styles.section}>
      <div className="wrap">
        <div style={styles.header}>
          <span className="eyebrow">The everyday annoyance</span>
          <h2 className="display" style={styles.h2}>
            You shouldn’t need a{' '}
            <span className="upright" style={{color: 'var(--spark)'}}>workaround</span>
            <br />
            to send yourself a link.
          </h2>
          <p style={styles.sub}>
            Shared clipboards only work between matching brands. AirDrop ignores
            Android. Quick Share ignores iPhone. So you end up emailing
            yourself, DMing yourself, or typing the URL by hand on a different
            keyboard. MagicShare just sends it.
          </p>
        </div>
        <div style={styles.grid} className="cmp-grid">
          <OldWayCol />
          <NewWayCol />
        </div>
      </div>
      <style>{`
        @media (max-width: 820px) {
          .cmp-grid { grid-template-columns: 1fr !important; }
        }
      `}</style>
    </section>
  );
}
