// Download CTA + Buy Me a Coffee donation card.

import {DownloadIcon, GithubIcon} from './Icons';

const styles = {
  cta: {
    position: 'relative',
    padding: '80px 40px',
    borderRadius: 28,
    overflow: 'hidden',
    textAlign: 'center',
    background:
      'radial-gradient(80% 100% at 50% 0%, color-mix(in oklch, var(--aura) 28%, transparent), transparent 60%), radial-gradient(60% 100% at 80% 100%, color-mix(in oklch, var(--spark) 20%, transparent), transparent 60%), linear-gradient(180deg, var(--bg-1), var(--bg-0))',
    border: '1px solid color-mix(in oklch, var(--aura) 35%, var(--line))',
  },
  ctaH: {fontSize: 'clamp(36px, 5vw, 64px)', margin: 0},
  ctaSub: {
    color: 'var(--ink-1)',
    fontSize: 16,
    maxWidth: 560,
    margin: '16px auto 0',
    lineHeight: 1.55,
  },
  platforms: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: 10,
    justifyContent: 'center',
    marginTop: 28,
  },
  plat: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 8,
    padding: '10px 16px',
    borderRadius: 999,
    border: '1px solid color-mix(in oklch, var(--aura) 40%, var(--line))',
    background: 'color-mix(in oklch, var(--aura) 8%, var(--bg-2))',
    color: 'var(--ink-1)',
    textDecoration: 'none',
    fontSize: 14,
    backdropFilter: 'blur(6px)',
  },
};

function PlatformBadge({name, glyph}) {
  return (
    <a href="#download" style={styles.plat}>
      <span style={{fontFamily: 'Geist Mono, monospace', fontSize: 12, color: 'var(--spark)'}}>
        {glyph}
      </span>
      {name}
    </a>
  );
}

export default function Download() {
  return (
    <section className="section" id="download" style={{paddingTop: 24}}>
      <div className="wrap">
        <div style={styles.cta}>
          <style>{`
            @keyframes drift-1 { 0%{transform:translate(0,0)} 50%{transform:translate(30px,-20px)} 100%{transform:translate(0,0)} }
            @keyframes drift-2 { 0%{transform:translate(0,0)} 50%{transform:translate(-24px,18px)} 100%{transform:translate(0,0)} }
          `}</style>
          <div
            style={{
              position: 'absolute',
              top: 30,
              left: 60,
              width: 6,
              height: 6,
              borderRadius: 999,
              background: 'var(--spark)',
              boxShadow: '0 0 12px var(--spark)',
              animation: 'drift-1 7s ease-in-out infinite',
            }}
          />
          <div
            style={{
              position: 'absolute',
              bottom: 50,
              right: 80,
              width: 5,
              height: 5,
              borderRadius: 999,
              background: 'var(--aura)',
              boxShadow: '0 0 12px var(--aura)',
              animation: 'drift-2 9s ease-in-out infinite',
            }}
          />

          <span className="eyebrow">Free · open source · Apache 2.0</span>
          <h2 className="display" style={{...styles.ctaH, marginTop: 14}}>
            Install once.{' '}
            <span className="upright" style={{color: 'var(--spark)'}}>Send forever.</span>
          </h2>
          <p style={styles.ctaSub}>
            MagicShare runs on every platform you do. Sign in with an anonymous
            account on each device — no email, no phone number — and they’ll
            just find each other.
          </p>

          <div style={styles.platforms}>
            <PlatformBadge name="macOS" glyph="⌘" />
            <PlatformBadge name="Windows" glyph="◧" />
            <PlatformBadge name="Linux" glyph="◇" />
            <PlatformBadge name="iOS" glyph="☍" />
            <PlatformBadge name="Android" glyph="◬" />
          </div>

          <div
            style={{
              display: 'flex',
              justifyContent: 'center',
              gap: 12,
              marginTop: 28,
              flexWrap: 'wrap',
            }}>
            <a
              href="https://github.com/mekedron/MagicShare/releases"
              target="_blank"
              rel="noopener noreferrer"
              className="btn btn-primary">
              <DownloadIcon /> Download MagicShare
            </a>
            <a
              href="https://github.com/mekedron/MagicShare"
              target="_blank"
              rel="noopener noreferrer"
              className="btn btn-ghost">
              <GithubIcon /> View on GitHub
            </a>
          </div>
        </div>

        {/* Donation card */}
        <div
          style={{
            marginTop: 64,
            padding: '48px 40px',
            borderRadius: 24,
            border: '1px solid color-mix(in oklch, var(--bmc-yellow-deep) 35%, var(--line))',
            background:
              'linear-gradient(135deg, color-mix(in oklch, var(--bmc-yellow) 8%, var(--bg-1)), color-mix(in oklch, var(--bmc-yellow-deep) 4%, var(--bg-1)))',
            position: 'relative',
            overflow: 'hidden',
            display: 'grid',
            gridTemplateColumns: '1fr auto',
            gap: 32,
            alignItems: 'center',
          }}
          className="donate-card">
          <span
            style={{
              position: 'absolute',
              top: 24,
              right: 120,
              width: 4,
              height: 4,
              borderRadius: 999,
              background: 'var(--bmc-yellow-deep)',
              opacity: 0.5,
              filter: 'blur(1px)',
              animation: 'drift-1 6s ease-in-out infinite',
            }}
          />
          <span
            style={{
              position: 'absolute',
              bottom: 30,
              left: 80,
              width: 6,
              height: 6,
              borderRadius: 999,
              background: 'var(--bmc-yellow)',
              opacity: 0.4,
              filter: 'blur(2px)',
              animation: 'drift-2 8s ease-in-out infinite',
            }}
          />

          <div>
            <span className="eyebrow" style={{color: 'var(--bmc-yellow-deep)'}}>
              Support the project
            </span>
            <h3
              className="display"
              style={{
                fontSize: 'clamp(28px, 3.5vw, 40px)',
                margin: '10px 0 12px',
                lineHeight: 1.1,
              }}>
              Like it?{' '}
              <span className="upright" style={{color: 'var(--bmc-yellow-deep)'}}>
                Buy me a coffee.
              </span>
            </h3>
            <p
              style={{
                color: 'var(--ink-1)',
                fontSize: 15,
                lineHeight: 1.55,
                maxWidth: 520,
                margin: 0,
              }}>
              MagicShare is a fork of{' '}
              <a
                href="https://github.com/localsend/localsend"
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  color: 'var(--ink-0)',
                  textDecoration: 'underline',
                  textUnderlineOffset: 2,
                }}>
                LocalSend
              </a>
              , maintained in spare evenings. If the fork's extra polish saves
              you a hassle, a small tip helps keep it alive — and a new feature
              on the roadmap.
            </p>
          </div>

          <a
            href="https://buymeacoffee.com/mekedron"
            target="_blank"
            rel="noopener noreferrer"
            className="donate-btn"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 10,
              padding: '16px 24px',
              borderRadius: 14,
              fontSize: 16,
              fontWeight: 600,
              textDecoration: 'none',
              color: 'var(--bmc-ink)',
              background: 'linear-gradient(135deg, var(--bmc-yellow), var(--bmc-yellow-deep))',
              border: '1px solid color-mix(in oklch, var(--bmc-yellow-deep) 60%, transparent)',
              boxShadow: '0 8px 24px -6px rgba(255, 184, 0, 0.55)',
              whiteSpace: 'nowrap',
              transition: 'transform 0.2s, box-shadow 0.2s',
            }}>
            <span style={{fontSize: 22}}>☕</span>
            <span>Buy me a coffee</span>
          </a>
        </div>
      </div>
      <style>{`
        @media (max-width: 720px) {
          .donate-card {
            grid-template-columns: 1fr !important;
            text-align: center;
            padding: 36px 24px !important;
          }
          .donate-card .donate-btn { justify-self: center; }
        }
      `}</style>
    </section>
  );
}
