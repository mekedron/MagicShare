// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// See: https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'MagicShare',
  tagline: 'Send a file or open a link on any device — even when it is offline.',
  favicon: 'img/favicon.ico',

  // Future flags — see https://docusaurus.io/docs/api/docusaurus-config#future
  // `v4` turns on every Docusaurus v4 preparation flag at once
  // (siteStorageNamespacing, fasterByDefault, mdx1CompatDisabledByDefault).
  // `faster` enables the new Rspack/SWC/LightningCSS build pipeline.
  future: {
    v4: true,
    faster: true,
  },

  // Production URL and base path for GitHub Pages
  // (project site at https://mekedron.github.io/MagicShare/).
  url: 'https://mekedron.github.io',
  baseUrl: '/MagicShare/',
  trailingSlash: false,

  // GitHub Pages deployment config.
  organizationName: 'mekedron',
  projectName: 'MagicShare',
  deploymentBranch: 'gh-pages',

  onBrokenLinks: 'throw',
  // Section anchors on the landing page (#cross, #how, #features, #download)
  // live inside React components, which Docusaurus cannot statically scan
  // — so it would flag them as broken. Downgrade to a warning rather than
  // failing the build.
  onBrokenAnchors: 'warn',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  // Geist (UI/body) + Instrument Serif (display) — used by the landing
  // page design. Preconnect first so the font CSS request starts early.
  headTags: [
    {
      tagName: 'link',
      attributes: {
        rel: 'preconnect',
        href: 'https://fonts.googleapis.com',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'preconnect',
        href: 'https://fonts.gstatic.com',
        crossorigin: 'anonymous',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'stylesheet',
        href:
          'https://fonts.googleapis.com/css2?' +
          'family=Instrument+Serif:ital@0;1&' +
          'family=Geist:wght@300;400;500;600;700&' +
          'family=Geist+Mono:wght@400;500&display=swap',
      },
    },
  ],

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          // Markdown lives at the repo root in `docs/`, while this
          // Docusaurus app lives in `docs-site/`. The path is resolved
          // relative to the Docusaurus root.
          path: '../docs',
          routeBasePath: 'docs',
          sidebarPath: './sidebars.js',
          editUrl:
            'https://github.com/mekedron/MagicShare/tree/main/docs/',
          // Files that live in `docs/` but are not meant for the
          // public site (e.g. agent prompts copied into Claude Code
          // sessions).
          exclude: ['**/ai-agent.md'],
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/docusaurus-social-card.jpg',
      // Dark first so the "magical" aurora reads strongest on first paint.
      // Honors the OS preference for repeat visitors.
      colorMode: {
        defaultMode: 'dark',
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'MagicShare',
        logo: {
          alt: 'MagicShare logo',
          src: 'img/logo.svg',
        },
        items: [
          // In-page anchors on `/`. Docusaurus resolves these to the
          // homepage from any other route.
          {to: '/#cross', label: 'Cross-platform', position: 'left'},
          {to: '/#how', label: 'How it works', position: 'left'},
          {to: '/#features', label: 'Features', position: 'left'},
          {
            type: 'docSidebar',
            sidebarId: 'tutorialSidebar',
            position: 'left',
            label: 'Docs',
          },
          {
            href: 'https://github.com/mekedron/MagicShare',
            position: 'right',
            className: 'header-github-link',
            'aria-label': 'GitHub repository',
            label: 'GitHub',
          },
          {
            href: 'https://buymeacoffee.com/mekedron',
            position: 'right',
            className: 'navbar-donate-link',
            label: 'Donate',
          },
          {
            to: '/#download',
            position: 'right',
            className: 'navbar-cta-link',
            label: 'Get the app',
          },
        ],
      },
      footer: {
        style: 'dark',
        logo: {
          alt: 'MagicShare logo',
          src: 'img/logo.svg',
          width: 32,
          height: 32,
        },
        links: [
          {
            title: 'Product',
            items: [
              {label: 'How it works', to: '/#how'},
              {label: 'Features', to: '/#features'},
              {label: 'Download', to: '/#download'},
            ],
          },
          {
            title: 'Documentation',
            items: [
              {label: 'Introduction', to: '/docs/intro'},
            ],
          },
          {
            title: 'Project',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/mekedron/MagicShare',
              },
              {
                label: 'Upstream (LocalSend)',
                href: 'https://github.com/localsend/localsend',
              },
              {
                label: '☕ Donate',
                href: 'https://buymeacoffee.com/mekedron',
              },
              {
                label: 'License',
                href:
                  'https://github.com/mekedron/MagicShare/blob/main/LICENSE',
              },
            ],
          },
        ],
        copyright: `© ${new Date().getFullYear()} MagicShare contributors. Apache License 2.0. Built on the LocalSend protocol.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
      },
    }),
};

export default config;
