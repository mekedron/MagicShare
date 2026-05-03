// Cross-platform showcase — segmented tabs (Send a link / a photo / a file)
// at the top, auto-cycles, pauses on hover. Devices look like real hardware
// (laptop with hinge, tablet with bezel, phone with notch).

import {useEffect, useLayoutEffect, useRef, useState} from 'react';

// Avoid the SSR warning React emits when useLayoutEffect runs on the server.
// Pure CSS layout falls back to useEffect during SSR; the pill snaps into
// place once the client mounts.
const useIsoLayoutEffect =
  typeof window !== 'undefined' ? useLayoutEffect : useEffect;

const styles = {
  section: {paddingTop: 24, paddingBottom: 72},
  header: {textAlign: 'center', maxWidth: 760, margin: '0 auto 32px'},
  h2: {fontSize: 'clamp(36px, 5vw, 64px)', marginTop: 12, lineHeight: 1.05},
  sub: {color: 'var(--ink-2)', marginTop: 24, fontSize: 16, lineHeight: 1.55},

  tabsWrap: {display: 'flex', justifyContent: 'center', marginBottom: 24},
  tabs: {
    position: 'relative',
    display: 'inline-flex',
    gap: 0,
    padding: 4,
    border: '1px solid var(--line)',
    borderRadius: 999,
    background: 'color-mix(in oklch, var(--bg-2) 70%, transparent)',
    backdropFilter: 'blur(8px)',
  },
  tabBtn: {
    position: 'relative',
    zIndex: 1,
    padding: '10px 20px',
    borderRadius: 999,
    fontSize: 14,
    fontFamily: 'inherit',
    color: 'var(--ink-2)',
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    transition: 'color 0.25s ease',
    display: 'inline-flex',
    alignItems: 'center',
    gap: 8,
    whiteSpace: 'nowrap',
  },
  tabBtnActive: {color: 'var(--ink-0)'},
  tabPill: {
    position: 'absolute',
    top: 4,
    bottom: 4,
    background: 'var(--bg-0)',
    borderRadius: 999,
    boxShadow:
      '0 1px 0 color-mix(in oklch, var(--ink-0) 8%, transparent), 0 0 0 1px var(--line-soft)',
    transition:
      'left 0.35s cubic-bezier(.7,.0,.3,1), width 0.35s cubic-bezier(.7,.0,.3,1)',
    zIndex: 0,
  },
  shell: {padding: 36, minHeight: 360},
  deviceRow: {
    display: 'flex',
    alignItems: 'flex-end',
    justifyContent: 'center',
    gap: 28,
    flexWrap: 'wrap',
  },
};

function BrowserPagePreview({url, accent, delay}) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        animation: `xp-page-in 6s ease-in-out ${delay}s infinite`,
        opacity: 0,
        display: 'flex',
        flexDirection: 'column',
      }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 5,
          height: 16,
          padding: '0 6px',
          flexShrink: 0,
          borderBottom: '1px solid var(--line-soft)',
          background: 'color-mix(in oklch, var(--bg-2) 80%, transparent)',
        }}>
        <span style={{width: 5, height: 5, borderRadius: 999, background: accent}} />
        <span
          style={{
            fontFamily: 'Geist Mono, monospace',
            fontSize: 7,
            color: 'var(--ink-2)',
            letterSpacing: '0.04em',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}>
          {url}
        </span>
      </div>
      <div style={{padding: 7, display: 'flex', flexDirection: 'column', gap: 4, flex: 1}}>
        <div style={{height: 4, width: '70%', borderRadius: 2, background: accent, opacity: 0.85}} />
        <div style={{height: 3, width: '92%', borderRadius: 2, background: 'var(--ink-3)', opacity: 0.5}} />
        <div style={{height: 3, width: '84%', borderRadius: 2, background: 'var(--ink-3)', opacity: 0.5}} />
        <div
          style={{
            height: '40%',
            width: '100%',
            borderRadius: 3,
            background: `color-mix(in oklch, ${accent} 22%, var(--bg-2))`,
            marginTop: 4,
          }}
        />
      </div>
    </div>
  );
}

function PhotoPreview({delay}) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        animation: `xp-photo-in 6s cubic-bezier(.2,.7,.2,1) ${delay}s infinite`,
        opacity: 0,
        transform: 'scale(0.6)',
        overflow: 'hidden',
      }}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(135deg, oklch(78% 0.16 60), oklch(64% 0.18 25) 45%, oklch(46% 0.20 305))',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: '62%',
          height: '38%',
          background: 'linear-gradient(180deg, oklch(54% 0.12 245), oklch(28% 0.06 265))',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: '62%',
          top: '26%',
          width: '26%',
          aspectRatio: '1/1',
          borderRadius: 999,
          background:
            'radial-gradient(circle at 40% 40%, oklch(94% 0.14 90), oklch(82% 0.18 70))',
          boxShadow: '0 0 14px oklch(82% 0.18 70)',
        }}
      />
    </div>
  );
}

function FilePreview({delay}) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        animation: `xp-page-in 6s ease-in-out ${delay}s infinite`,
        opacity: 0,
        display: 'flex',
        flexDirection: 'column',
        padding: 8,
        gap: 5,
      }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          padding: '5px 6px',
          borderRadius: 4,
          background: 'color-mix(in oklch, var(--spark) 14%, var(--bg-2))',
          border: '1px solid color-mix(in oklch, var(--spark) 35%, transparent)',
        }}>
        <span
          style={{
            width: 14,
            height: 16,
            borderRadius: 2,
            background: 'color-mix(in oklch, var(--spark) 25%, var(--bg-1))',
            border: '1px solid color-mix(in oklch, var(--spark) 50%, transparent)',
            flexShrink: 0,
          }}
        />
        <span
          style={{
            fontFamily: 'Geist Mono, monospace',
            fontSize: 7,
            color: 'var(--ink-1)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}>
          report.pdf
        </span>
      </div>
      <div style={{height: 3, width: '60%', borderRadius: 2, background: 'var(--ink-3)', opacity: 0.4}} />
      <div style={{height: 3, width: '40%', borderRadius: 2, background: 'var(--ink-3)', opacity: 0.3}} />
    </div>
  );
}

function LaptopFrame({width = 240, content, label}) {
  const lidH = Math.round(width * 0.62);
  return (
    <div style={{width, display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
      <div
        style={{
          width: '100%',
          height: lidH,
          borderRadius: '12px 12px 4px 4px',
          background: 'linear-gradient(180deg, #2a2a2e, #1a1a1e)',
          padding: 8,
          boxShadow:
            '0 12px 24px -14px rgba(0,0,0,0.4), inset 0 0 0 1px rgba(255,255,255,0.04)',
          position: 'relative',
        }}>
        <span
          style={{
            position: 'absolute',
            top: 3,
            left: '50%',
            transform: 'translateX(-50%)',
            width: 3,
            height: 3,
            borderRadius: 999,
            background: '#444',
          }}
        />
        <div
          style={{
            width: '100%',
            height: '100%',
            borderRadius: 3,
            background: 'var(--device-screen, var(--bg-1))',
            overflow: 'hidden',
            position: 'relative',
          }}>
          {content}
        </div>
      </div>
      <div
        style={{
          width: '108%',
          height: 6,
          background: 'linear-gradient(180deg, #3a3a3e, #1a1a1e)',
          borderRadius: '0 0 6px 6px',
          position: 'relative',
          boxShadow: '0 4px 8px -4px rgba(0,0,0,0.3)',
        }}>
        <span
          style={{
            position: 'absolute',
            top: 0,
            left: '50%',
            transform: 'translateX(-50%)',
            width: '20%',
            height: 2,
            background: 'rgba(0,0,0,0.4)',
            borderRadius: '0 0 4px 4px',
          }}
        />
      </div>
      <span
        style={{
          fontFamily: 'Geist Mono, monospace',
          fontSize: 9,
          letterSpacing: '0.18em',
          color: 'var(--ink-3)',
          marginTop: 12,
        }}>
        {label}
      </span>
    </div>
  );
}

function PhoneFrame({width = 90, content, label}) {
  const h = Math.round(width * 2.05);
  return (
    <div style={{width, display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
      <div
        style={{
          width: '100%',
          height: h,
          borderRadius: 16,
          background: 'linear-gradient(180deg, #2a2a2e, #1a1a1e)',
          padding: 4,
          boxShadow:
            '0 12px 24px -14px rgba(0,0,0,0.4), inset 0 0 0 1px rgba(255,255,255,0.05)',
          position: 'relative',
        }}>
        <div
          style={{
            width: '100%',
            height: '100%',
            borderRadius: 12,
            background: 'var(--device-screen, var(--bg-1))',
            overflow: 'hidden',
            position: 'relative',
          }}>
          {content}
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: '50%',
              transform: 'translateX(-50%)',
              width: '40%',
              height: 12,
              background: '#0a0a0a',
              borderRadius: '0 0 8px 8px',
              zIndex: 2,
            }}
          />
          <div
            style={{
              position: 'absolute',
              bottom: 4,
              left: '50%',
              transform: 'translateX(-50%)',
              width: '32%',
              height: 2,
              background: 'rgba(255,255,255,0.5)',
              borderRadius: 999,
              zIndex: 2,
            }}
          />
        </div>
      </div>
      <span
        style={{
          fontFamily: 'Geist Mono, monospace',
          fontSize: 9,
          letterSpacing: '0.18em',
          color: 'var(--ink-3)',
          marginTop: 12,
        }}>
        {label}
      </span>
    </div>
  );
}

function TabletFrame({width = 150, content, label}) {
  const h = Math.round(width * 1.35);
  return (
    <div style={{width, display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
      <div
        style={{
          width: '100%',
          height: h,
          borderRadius: 14,
          background: 'linear-gradient(180deg, #2a2a2e, #1a1a1e)',
          padding: 6,
          boxShadow:
            '0 12px 24px -14px rgba(0,0,0,0.4), inset 0 0 0 1px rgba(255,255,255,0.05)',
          position: 'relative',
        }}>
        <span
          style={{
            position: 'absolute',
            top: 6,
            left: '50%',
            transform: 'translateX(-50%)',
            width: 3,
            height: 3,
            borderRadius: 999,
            background: '#444',
            zIndex: 3,
          }}
        />
        <div
          style={{
            width: '100%',
            height: '100%',
            borderRadius: 8,
            background: 'var(--device-screen, var(--bg-1))',
            overflow: 'hidden',
            position: 'relative',
          }}>
          {content}
        </div>
      </div>
      <span
        style={{
          fontFamily: 'Geist Mono, monospace',
          fontSize: 9,
          letterSpacing: '0.18em',
          color: 'var(--ink-3)',
          marginTop: 12,
        }}>
        {label}
      </span>
    </div>
  );
}

function SourceCard({mode}) {
  const meta = {
    link: {
      eyebrow: 'YOU PASTE A LINK',
      body: (
        <div
          style={{
            padding: '14px 16px',
            borderRadius: 10,
            border: '1px solid var(--line)',
            background: 'color-mix(in oklch, var(--bg-1) 70%, transparent)',
          }}>
          <div
            style={{
              fontSize: 11,
              color: 'var(--ink-3)',
              marginBottom: 6,
              fontFamily: 'Geist Mono, monospace',
              letterSpacing: '0.1em',
            }}>
            CLIPBOARD
          </div>
          <div
            style={{
              fontFamily: 'Geist Mono, monospace',
              fontSize: 13,
              color: 'var(--ink-1)',
              lineHeight: 1.4,
              wordBreak: 'break-all',
            }}>
            <span style={{color: 'var(--spark)'}}>https://</span>example.com/article
          </div>
        </div>
      ),
    },
    photo: {
      eyebrow: 'YOU PICK A PHOTO',
      body: (
        <div
          style={{
            position: 'relative',
            aspectRatio: '16/10',
            borderRadius: 10,
            overflow: 'hidden',
            border: '1px solid var(--line)',
          }}>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background:
                'linear-gradient(135deg, oklch(78% 0.16 60), oklch(64% 0.18 25) 45%, oklch(46% 0.20 305))',
            }}
          />
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: '62%',
              height: '38%',
              background:
                'linear-gradient(180deg, oklch(54% 0.12 245), oklch(28% 0.06 265))',
            }}
          />
          <div
            style={{
              position: 'absolute',
              left: '62%',
              top: '26%',
              width: '26%',
              aspectRatio: '1/1',
              borderRadius: 999,
              background:
                'radial-gradient(circle at 40% 40%, oklch(94% 0.14 90), oklch(82% 0.18 70))',
            }}
          />
          <span
            style={{
              position: 'absolute',
              left: 10,
              bottom: 10,
              fontFamily: 'Geist Mono, monospace',
              fontSize: 10,
              letterSpacing: '0.14em',
              color: 'white',
              textShadow: '0 1px 2px rgba(0,0,0,0.4)',
            }}>
            SUNSET.JPG
          </span>
        </div>
      ),
    },
    file: {
      eyebrow: 'YOU DROP A FILE',
      body: (
        <div
          style={{
            padding: '16px 16px',
            borderRadius: 10,
            border: '1px dashed var(--line)',
            background: 'color-mix(in oklch, var(--bg-1) 70%, transparent)',
            display: 'flex',
            alignItems: 'center',
            gap: 12,
          }}>
          <div
            style={{
              width: 38,
              height: 46,
              borderRadius: 4,
              background: 'color-mix(in oklch, var(--spark) 25%, var(--bg-1))',
              border: '1px solid color-mix(in oklch, var(--spark) 50%, transparent)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: 'Geist Mono, monospace',
              fontSize: 9,
              fontWeight: 600,
              color: 'var(--spark)',
              letterSpacing: '0.1em',
            }}>
            PDF
          </div>
          <div style={{flex: 1, minWidth: 0}}>
            <div
              style={{
                fontFamily: 'Geist Mono, monospace',
                fontSize: 12,
                color: 'var(--ink-1)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}>
              quarterly-report.pdf
            </div>
            <div style={{fontSize: 11, color: 'var(--ink-3)', marginTop: 3}}>2.4 MB</div>
          </div>
        </div>
      ),
    },
  }[mode];

  return (
    <div
      style={{
        width: 280,
        display: 'flex',
        flexDirection: 'column',
        gap: 14,
        padding: 18,
        border: '1px solid var(--line-soft)',
        borderRadius: 14,
        background: 'color-mix(in oklch, var(--bg-2) 50%, transparent)',
      }}>
      <span
        style={{
          fontFamily: 'Geist Mono, monospace',
          fontSize: 10,
          letterSpacing: '0.2em',
          color: 'var(--ink-3)',
        }}>
        {meta.eyebrow}
      </span>
      {meta.body}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          marginTop: 'auto',
          padding: '10px 14px',
          borderRadius: 10,
          background: 'color-mix(in oklch, var(--spark) 14%, var(--bg-1))',
          border: '1px solid color-mix(in oklch, var(--spark) 40%, transparent)',
          fontSize: 13,
          color: 'var(--ink-0)',
        }}>
        <span
          style={{
            width: 8,
            height: 8,
            borderRadius: 999,
            background: 'var(--spark)',
            boxShadow: '0 0 10px var(--spark)',
          }}
        />
        <span style={{whiteSpace: 'nowrap'}}>
          Sent to <strong style={{fontWeight: 500}}>every device</strong>
        </span>
      </div>
    </div>
  );
}

function DeviceContent({mode, kind, delay}) {
  const accent = 'oklch(72% 0.18 200)';
  if (mode === 'link') {
    const url = kind === 'phone' ? 'ex.com' : 'example.com/article';
    return <BrowserPagePreview url={url} accent={accent} delay={delay} />;
  }
  if (mode === 'photo') return <PhotoPreview delay={delay} />;
  return <FilePreview delay={delay} />;
}

const TABS = [
  {id: 'link', label: 'Send a link'},
  {id: 'photo', label: 'Send a photo'},
  {id: 'file', label: 'Send a file'},
];

export default function CrossPlatformShowcase() {
  const [mode, setMode] = useState('link');
  const [paused, setPaused] = useState(false);
  const tabsRef = useRef(null);
  const [pill, setPill] = useState({left: 4, width: 0});

  useEffect(() => {
    if (paused) return;
    const t = setTimeout(() => {
      setMode((m) => {
        const i = TABS.findIndex((tab) => tab.id === m);
        return TABS[(i + 1) % TABS.length].id;
      });
    }, 5500);
    return () => clearTimeout(t);
  }, [mode, paused]);

  useIsoLayoutEffect(() => {
    const wrap = tabsRef.current;
    if (!wrap) return;
    const btn = wrap.querySelector(`[data-tab-id="${mode}"]`);
    if (!btn) return;
    const wrapBox = wrap.getBoundingClientRect();
    const btnBox = btn.getBoundingClientRect();
    setPill({left: btnBox.left - wrapBox.left, width: btnBox.width});
  }, [mode]);

  return (
    <section className="section" id="cross" style={styles.section}>
      <div className="wrap">
        <div style={styles.header}>
          <span className="eyebrow">Cross-platform, for real</span>
          <h2 className="display" style={styles.h2}>
            Mac. Windows. Linux. iPhone. Android.
            <br />
            <span className="upright" style={{color: 'var(--beam)'}}>One app.</span>
          </h2>
          <p style={styles.sub}>
            AirDrop only talks to other Apple gear. Quick Share skips iPhones.
            MagicShare doesn't care what you own — paste a link, pick a photo,
            or drop a file, and it shows up on every device.
          </p>
        </div>

        <div style={styles.tabsWrap}>
          <div
            ref={tabsRef}
            style={styles.tabs}
            onMouseEnter={() => setPaused(true)}
            onMouseLeave={() => setPaused(false)}>
            <span style={{...styles.tabPill, left: pill.left, width: pill.width}} />
            {TABS.map((t) => (
              <button
                key={t.id}
                data-tab-id={t.id}
                onClick={() => setMode(t.id)}
                style={{...styles.tabBtn, ...(t.id === mode ? styles.tabBtnActive : {})}}>
                {t.label}
              </button>
            ))}
          </div>
        </div>

        <div
          className="card xp-shell"
          style={styles.shell}
          onMouseEnter={() => setPaused(true)}
          onMouseLeave={() => setPaused(false)}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 32,
              justifyContent: 'center',
              flexWrap: 'wrap',
            }}>
            <SourceCard mode={mode} />

            <div
              className="xp-connector"
              style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 6,
                fontFamily: 'Geist Mono, monospace',
                fontSize: 10,
                letterSpacing: '0.18em',
                color: 'var(--ink-3)',
              }}>
              <span>BEAM</span>
              <svg width="60" height="14" viewBox="0 0 60 14" fill="none">
                <path d="M2 7 H54" stroke="var(--spark)" strokeWidth="1.5" strokeDasharray="4 3" />
                <path
                  d="M48 2 L56 7 L48 12"
                  stroke="var(--spark)"
                  strokeWidth="1.5"
                  fill="none"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </div>

            <div style={styles.deviceRow}>
              <LaptopFrame
                width={220}
                label="MAC"
                content={<DeviceContent mode={mode} kind="laptop" delay={0.2} />}
              />
              <TabletFrame
                width={130}
                label="iPAD"
                content={<DeviceContent mode={mode} kind="tablet" delay={0.7} />}
              />
              <PhoneFrame
                width={82}
                label="PIXEL"
                content={<DeviceContent mode={mode} kind="phone" delay={1.2} />}
              />
            </div>
          </div>
        </div>
      </div>

      <style>{`
        @keyframes xp-page-in {
          0%      { opacity: 0; transform: translateY(6px); }
          15%     { opacity: 0.4; }
          25%     { opacity: 1; transform: translateY(0); }
          88%     { opacity: 1; transform: translateY(0); }
          100%    { opacity: 1; }
        }
        @keyframes xp-photo-in {
          0%      { opacity: 0; transform: scale(0.7); }
          15%     { opacity: 0.4; transform: scale(0.85); }
          25%     { opacity: 1; transform: scale(1); }
          88%     { opacity: 1; transform: scale(1); }
          100%    { opacity: 1; transform: scale(1); }
        }
        @media (max-width: 760px) {
          #cross .xp-connector { display: none !important; }
          #cross .xp-shell { padding: 24px !important; }
        }
      `}</style>
    </section>
  );
}
