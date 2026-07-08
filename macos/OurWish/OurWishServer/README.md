# OurWishServer

Standalone HTTP backend for OurWish.

## Runtime configuration

- `OURWISH_PORT`: HTTP port. Defaults to `8420`.
- `OURWISH_DB_PATH`: SQLite path override. Useful for container or staging runs.

## Docker build

Build from the `macos/OurWish` directory:

```bash
docker build -f Dockerfile.server -t ourwish-server .
```

Run:

```bash
docker run --rm -p 8420:8420 \
  -e OURWISH_PORT=8420 \
  -e OURWISH_DB_PATH=/data/ourwish.db \
  -v "$PWD/.data:/data" \
  ourwish-server
```

## Notes

- Product-image auto-fetch currently relies on Apple frameworks when running on macOS.
- On non-macOS platforms the backend still runs, but product-image scraping falls back to no-op until a cross-platform fetcher is added.
