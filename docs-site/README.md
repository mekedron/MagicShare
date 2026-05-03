# MagicShare — Documentation Site

A [Docusaurus 3.10](https://docusaurus.io/blog/releases/3.10) static site
documenting MagicShare.

The site enables Docusaurus's `future.v4: true` and `future.faster: true`
flags so the build runs on the Rspack/SWC/LightningCSS pipeline that will
become the default in Docusaurus v4.

## Repository layout

```
.
├── docs/        ← markdown content (intro, future guides)
└── docs-site/   ← this directory: Docusaurus app, build tooling, theme
```

The Docusaurus config (`docusaurus.config.js`) reads markdown from
`../docs` so contributors editing content do not need to touch the
JavaScript build setup.

## Local development

From this directory:

```bash
npm install
npm start
```

This starts a hot-reloading dev server at <http://localhost:3000/MagicShare/>.

## Production build

```bash
npm run build
```

Outputs the static site to `docs-site/build/`.

## Deployment

The site is deployed automatically to **GitHub Pages** by the workflow in
[`.github/workflows/deploy-docs.yml`](../.github/workflows/deploy-docs.yml)
on every push to `main` that touches `docs/`, `docs-site/`, or the
workflow files. PRs trigger a build-only check via
[`.github/workflows/test-deploy-docs.yml`](../.github/workflows/test-deploy-docs.yml).

The published URL is <https://mekedron.github.io/MagicShare/>.

To enable deployment, in the GitHub repository settings:

1. Go to **Settings → Pages**.
2. Set **Source** to **GitHub Actions**.

No further configuration is required — the workflow handles the rest.
