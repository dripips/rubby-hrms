# Landing page

One-pager served via **GitHub Pages**.

## Setup (one-time)

1. GitHub → Repo → **Settings → Pages**
2. **Source**: Deploy from a branch
3. **Branch**: `master` · folder `/docs`
4. **Custom domain** (optional): add a `CNAME` file in `docs/` with your domain (e.g. `hrms.example.com`) + configure DNS:
   ```
   CNAME hrms.example.com → dripips.github.io
   ```

After save, the page is live at `https://dripips.github.io/rubby-hrms/` (or your custom domain) within ~1 minute.

## Files

| File | What |
|---|---|
| `index.html`        | One-page landing |
| `style.css`         | Apple-HIG design tokens |
| `screenshots/{ru,en,de}/` | Auto-captured app screenshots (used by `index.html` and main README) |

## Regenerating screenshots

With the Rails app running on `:4000`:

```bash
bin/rails screenshots
```

This captures 15 light + 4 dark screenshots per locale (RU / EN / DE) into `docs/screenshots/`. The landing page links to the English ones directly via GitHub's raw content URLs.
