// How it works — three friendly stages, no jargon.
//   1. Drop or paste.
//   2. Pick a device (or many).
//   3. It shows up — file lands, link opens.

import {CheckIcon} from './Icons';

const styles = {
  section: {paddingTop: 24, paddingBottom: 96},
  header: {textAlign: 'center', maxWidth: 720, margin: '0 auto 64px'},
  h2: {fontSize: 'clamp(36px, 5vw, 64px)', marginTop: 12},
  sub: {color: 'var(--ink-2)', marginTop: 18, fontSize: 16, lineHeight: 1.55},
  steps: {display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 20},
  step: {padding: 26, display: 'flex', flexDirection: 'column', gap: 18, minHeight: 380},
  num: {
    fontFamily: 'Instrument Serif, serif',
    fontStyle: 'italic',
    fontSize: 36,
    lineHeight: 1,
    color: 'var(--ink-3)',
  },
  title: {color: 'var(--ink-0)', fontWeight: 500, fontSize: 20, letterSpacing: '-0.01em'},
  body: {color: 'var(--ink-2)', fontSize: 14, lineHeight: 1.6},
  diagram: {
    height: 160,
    borderRadius: 14,
    border: '1px solid var(--line-soft)',
    background: 'color-mix(in oklch, var(--bg-2) 50%, transparent)',
    position: 'relative',
    overflow: 'hidden',
  },
  tag: {
    position: 'absolute',
    top: 10,
    left: 12,
    fontFamily: 'Geist Mono, monospace',
    fontSize: 10,
    letterSpacing: '0.18em',
    color: 'var(--ink-3)',
  },
};

function DropDiagram() {
  return (
    <div style={styles.diagram}>
      <span style={styles.tag}>DROP OR PASTE</span>
      <style>{`
        @keyframes drop-fall {
          0%   { transform: translate(-50%, -42px) rotate(-6deg); opacity: 0; }
          15%  { opacity: 1; }
          50%  { transform: translate(-50%, 18px) rotate(0deg); }
          100% { transform: translate(-50%, 14px) rotate(0deg); opacity: 1; }
        }
        @keyframes hot-glow {
          0%, 40% { box-shadow: 0 0 0 0 transparent; border-color: var(--line); }
          55%     { box-shadow: 0 0 24px color-mix(in oklch, var(--spark) 35%, transparent); border-color: color-mix(in oklch, var(--spark) 70%, transparent); }
          100%    { box-shadow: 0 0 0 0 transparent; border-color: var(--line); }
        }
      `}</style>
      <div
        style={{
          position: 'absolute',
          left: '50%',
          top: 60,
          width: 100,
          height: 70,
          borderRadius: 10,
          border: '1px dashed color-mix(in oklch, var(--spark) 60%, transparent)',
          background: 'color-mix(in oklch, var(--spark) 8%, transparent)',
          transform: 'translateX(-50%)',
          display: 'grid',
          placeItems: 'center',
          animation: 'hot-glow 4s ease-in-out infinite',
        }}>
        <span
          className="mono"
          style={{fontSize: 10, color: 'var(--spark)', letterSpacing: '0.14em'}}>
          HOT ZONE
        </span>
      </div>
      <div
        style={{
          position: 'absolute',
          left: '50%',
          top: 18,
          width: 38,
          height: 46,
          borderRadius: 6,
          background: 'color-mix(in oklch, var(--spark) 25%, var(--bg-1))',
          border: '1px solid color-mix(in oklch, var(--spark) 60%, transparent)',
          animation: 'drop-fall 4s ease-in-out infinite',
          display: 'grid',
          placeItems: 'center',
          boxShadow: '0 6px 24px color-mix(in oklch, var(--spark) 28%, transparent)',
        }}>
        <span
          className="mono"
          style={{fontSize: 9, color: 'var(--spark)', letterSpacing: '0.1em'}}>
          .png
        </span>
      </div>
    </div>
  );
}

function PickDiagram() {
  return (
    <div style={styles.diagram}>
      <span style={styles.tag}>PICK A DEVICE</span>
      <style>{`
        @keyframes pick-a { 0%,15%{opacity:.5; border-color:var(--line-soft)} 25%{opacity:1;} 100%{opacity:1;} }
        @keyframes pick-b { 0%,40%{opacity:.5;} 50%{opacity:1;} 100%{opacity:1;} }
        @keyframes pick-c { 0%,65%{opacity:.5;} 75%{opacity:1;} 100%{opacity:1;} }
        @keyframes check-pop { 0%,18%{opacity:0; transform:scale(0.4);} 28%{opacity:1; transform:scale(1);} 100%{opacity:1; transform:scale(1);} }
      `}</style>
      <div
        style={{
          position: 'absolute',
          inset: '44px 22px 22px',
          display: 'flex',
          flexDirection: 'column',
          gap: 8,
        }}>
        {[
          {name: 'Pixel', anim: 'pick-a', checkAnim: 'check-pop', checkD: 0},
          {name: 'iPad', anim: 'pick-b', checkAnim: 'check-pop', checkD: 1},
          {name: 'Win PC', anim: 'pick-c', checkAnim: 'check-pop', checkD: 2},
        ].map((d) => (
          <div
            key={d.name}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '8px 12px',
              borderRadius: 999,
              border: '1px solid color-mix(in oklch, var(--aura) 55%, transparent)',
              background: 'color-mix(in oklch, var(--aura) 14%, var(--bg-1))',
              fontSize: 12,
              color: 'var(--ink-1)',
              animation: `${d.anim} 4s ease-in-out infinite`,
            }}>
            <span
              style={{
                width: 16,
                height: 16,
                borderRadius: 999,
                border: '1.5px solid color-mix(in oklch, var(--aura) 70%, transparent)',
                background: 'color-mix(in oklch, var(--aura) 30%, var(--bg-1))',
                display: 'grid',
                placeItems: 'center',
                color: 'var(--spark)',
              }}>
              <span style={{animation: `${d.checkAnim} 4s ease-in-out ${d.checkD * 0.05}s infinite`}}>
                <CheckIcon size={10} />
              </span>
            </span>
            {d.name}
          </div>
        ))}
      </div>
    </div>
  );
}

function ArriveDiagram() {
  return (
    <div style={styles.diagram}>
      <span style={styles.tag}>IT SHOWS UP</span>
      <style>{`
        @keyframes file-arr { 0%,30%{opacity:0; transform:translate(-30px,0) scale(0.7);} 45%{opacity:1; transform:translate(0,0) scale(1);} 100%{opacity:1;} }
        @keyframes link-arr { 0%,55%{opacity:0; transform:translateY(8px);} 68%{opacity:1; transform:translateY(0);} 100%{opacity:1;} }
      `}</style>
      <div
        style={{
          position: 'absolute',
          inset: '40px 18px 18px',
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 10,
        }}>
        <div
          style={{
            padding: 10,
            borderRadius: 10,
            border: '1px solid color-mix(in oklch, var(--beam) 50%, transparent)',
            background: 'color-mix(in oklch, var(--beam) 12%, var(--bg-1))',
            display: 'flex',
            flexDirection: 'column',
            gap: 6,
            animation: 'file-arr 4s ease-in-out infinite',
          }}>
          <div className="mono" style={{fontSize: 9, color: 'var(--ink-3)', letterSpacing: '0.14em'}}>
            FILE
          </div>
          <div style={{fontSize: 11, color: 'var(--ink-0)', fontWeight: 500}}>screenshot.png</div>
          <div style={{height: 3, borderRadius: 999, background: 'var(--beam)', width: '100%'}} />
        </div>
        <div
          style={{
            padding: 10,
            borderRadius: 10,
            border: '1px solid color-mix(in oklch, var(--spark) 50%, transparent)',
            background: 'color-mix(in oklch, var(--spark) 10%, var(--bg-1))',
            display: 'flex',
            flexDirection: 'column',
            gap: 6,
            animation: 'link-arr 4s ease-in-out infinite',
          }}>
          <div className="mono" style={{fontSize: 9, color: 'var(--ink-3)', letterSpacing: '0.14em'}}>
            LINK
          </div>
          <div style={{fontSize: 11, color: 'var(--ink-0)', fontWeight: 500}}>example.com</div>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              color: 'oklch(72% 0.18 150)',
              fontSize: 10,
            }}>
            <span
              style={{
                width: 6,
                height: 6,
                borderRadius: 999,
                background: 'oklch(72% 0.18 150)',
              }}
            />
            opened
          </div>
        </div>
      </div>
    </div>
  );
}

export default function HowItWorks() {
  const steps = [
    {
      n: '01',
      diagram: <DropDiagram />,
      title: 'Drop or paste',
      body:
        'Drag a file onto MagicShare, or onto the screen-corner hot zone. Paste a link to send a URL instead.',
    },
    {
      n: '02',
      diagram: <PickDiagram />,
      title: 'Pick where it goes',
      body:
        'Pick a device. Or many — fan out to your phone, tablet and laptop in one shot. They’re always there in the list.',
    },
    {
      n: '03',
      diagram: <ArriveDiagram />,
      title: 'It just shows up',
      body:
        'Files land in Downloads. Links open in the default browser. Even if the app wasn’t already open on the other side.',
    },
  ];

  return (
    <section className="section" id="how" style={styles.section}>
      <div className="wrap">
        <div style={styles.header}>
          <span className="eyebrow">How it works</span>
          <h2 className="display" style={styles.h2}>
            Three steps. <span className="upright" style={{color: 'var(--aura)'}}>Zero ceremony.</span>
          </h2>
          <p style={styles.sub}>
            Files travel directly between your devices, end-to-end encrypted —
            never through a third-party server. The internet is only used so
            your devices can find each other.
          </p>
        </div>

        <div style={styles.steps} className="how-steps">
          {steps.map((s) => (
            <div key={s.n} className="card" style={styles.step}>
              <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start'}}>
                <span className="display" style={styles.num}>
                  {s.n}
                </span>
                <span
                  className="mono"
                  style={{fontSize: 10, color: 'var(--ink-3)', letterSpacing: '0.18em'}}>
                  STEP
                </span>
              </div>
              {s.diagram}
              <div>
                <div style={styles.title}>{s.title}</div>
                <p style={{...styles.body, marginTop: 8, marginBottom: 0}}>{s.body}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
      <style>{`
        @media (max-width: 900px) {
          .how-steps { grid-template-columns: 1fr !important; }
        }
      `}</style>
    </section>
  );
}
