# Landing page (3 locales)

One-pager served via **GitHub Pages**. Three languages, language switcher in the topbar (EN ↔ RU ↔ DE).

| Locale | URL | File |
|---|---|---|
| English (default) | `https://dripips.github.io/rubby-hrms/`     | `docs/index.html`      |
| Русский           | `https://dripips.github.io/rubby-hrms/ru/`  | `docs/ru/index.html`   |
| Deutsch           | `https://dripips.github.io/rubby-hrms/de/`  | `docs/de/index.html`   |

All three share `docs/style.css`. Screenshots come from `docs/screenshots/{ru,en,de}/` via GitHub raw URLs — each landing always shows the matching-locale UI in screenshots.

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
| `index.html` / `ru/index.html` / `de/index.html` | Per-locale landing |
| `style.css`         | Apple-HIG design tokens — shared by all 3 locales |
| `screenshots/{ru,en,de}/` | Auto-captured app screenshots |

## Regenerating screenshots

With the Rails app running on `:4000`:

```bash
bin/rails screenshots
```

This captures 15 light + 4 dark screenshots per locale (RU / EN / DE) into `docs/screenshots/`. Each landing page references its locale's folder directly.

## Adding a new locale

1. Translate `docs/index.html` to a new file `docs/<locale>/index.html`
2. Add a link to the `lang-switcher` in topbars of all existing locales
3. Add the locale to the `screenshots:all` rake task (already does ru/en/de) — if you want auto-screenshots in the new locale
