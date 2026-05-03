import Layout from '@theme/Layout';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

import Hero from '@site/src/components/landing/Hero';
import CrossPlatformShowcase from '@site/src/components/landing/CrossPlatformShowcase';
import Comparison from '@site/src/components/landing/Comparison';
import Connect from '@site/src/components/landing/Connect';
import HowItWorks from '@site/src/components/landing/HowItWorks';
import Features from '@site/src/components/landing/Features';
import Download from '@site/src/components/landing/Download';

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="MagicShare — send a file or open a link on any device, even when it is offline, on a different platform, or signed into a different account.">
      <div className="landing-page">
        <main>
          <Hero />
          <CrossPlatformShowcase />
          <Comparison />
          <Connect />
          <HowItWorks />
          <Features />
          <Download />
        </main>
      </div>
    </Layout>
  );
}
