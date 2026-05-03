import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Cross-device, cross-platform',
    Svg: require('@site/static/img/undraw_docusaurus_mountain.svg').default,
    description: (
      <>
        Send files and open links between macOS, Windows, Linux, Android, and
        iOS — no shared Apple ID, Google account, or messenger needed.
      </>
    ),
  },
  {
    title: 'Wake-up via push, transfer peer-to-peer',
    Svg: require('@site/static/img/undraw_docusaurus_tree.svg').default,
    description: (
      <>
        A tiny encrypted push wakes the target device. The actual file or link
        travels directly between devices over the LocalSend protocol.
      </>
    ),
  },
  {
    title: 'Drop, pick, send',
    Svg: require('@site/static/img/undraw_docusaurus_react.svg').default,
    description: (
      <>
        Drag a file onto MagicShare, paste a link, pick one or more of your
        devices, and you are done. The other side gets a notification — one
        tap and the link opens or the download starts.
      </>
    ),
  },
];

function Feature({Svg, title, description}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
