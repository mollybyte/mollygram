# mollygram.dev

The project website: one static page, built from the accepted design in
[`design/website/`](../design/website) (direction A, "Window"). Light and dark
follow the visitor's system setting. The app screens are drawn in HTML and CSS
in `src/shots.mjs`, so there are no screenshots to keep in sync.

```sh
node build.mjs          # writes dist/
npm run preview         # builds and serves dist/ on http://localhost:4321
```

No dependencies: the build is plain Node (22 or newer). Layout:

| Path | What |
| --- | --- |
| `src/index.html` | Page template; `{{SHOT:Screen}}` placeholders become app screens |
| `src/site.css` | Page and app screen styles, inlined into the page at build time |
| `src/shots.mjs` | App screens: Chat, Palette, Split, Privacy, Plugins |
| `public/` | Copied as is: icons, `og.png`, `_headers`, robots, sitemap |
| `scripts/icons.py` | Rebuilds the icons in `public/` from `assets/icon` |
| `scripts/og.mjs` | Rebuilds `public/og.png` from the built page (needs Playwright) |

## Deploys

[`.github/workflows/website.yml`](../.github/workflows/website.yml) deploys to
the Cloudflare Pages project `mollygram` with Wrangler: production from `main`,
a preview for every pull request that touches `website/`. It needs two
repository secrets, `CLOUDFLARE_API_TOKEN` (Account, Cloudflare Pages, Edit)
and `CLOUDFLARE_ACCOUNT_ID`; without them the workflow only builds. The first
deploy creates the Pages project. The custom domain mollygram.dev is attached
to the project in the Cloudflare dashboard.
