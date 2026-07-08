# OurWish PWA

## API configuration

The PWA can run in either of these modes:

- same-origin with the embedded/standalone Swift backend
- remote API mode against a hosted backend

Use a `.env` file based on `.env.example`.

Examples:

```bash
# Local Vite dev, proxying to the Swift server
VITE_API_BASE_URL=
VITE_DEV_API_PROXY_TARGET=http://localhost:8420
```

```bash
# Production build against a hosted backend
VITE_API_BASE_URL=https://api.example.com
```

When `VITE_API_BASE_URL` is empty, the app keeps using relative `/api/...` routes.

## Notes

- The current app still expects the existing OurWish REST contract.
- The native macOS app has not yet been switched to remote-backed stores in this phase.

This template provides a minimal setup to get React working in Vite with HMR and some Oxlint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend enabling type-aware lint rules by installing `oxlint-tsgolint` and editing `.oxlintrc.json`:

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "oxc"],
  "options": {
    "typeAware": true
  },
  "rules": {
    "react/rules-of-hooks": "error",
    "react/only-export-components": ["warn", { "allowConstantExport": true }]
  }
}
```

See the [Oxlint rules documentation](https://oxc.rs/docs/guide/usage/linter/rules) for the full list of rules and categories.
