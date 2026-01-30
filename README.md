promote-release downloads GitHub Actions artifacts from a workflow run, packs them into `.tar.gz` archives, and uploads them to a GitHub Release.

### How it works

promote-release calls `gh run download` to fetch all artifacts from a given workflow run. If artifacts arrive as `.zip` files, they are extracted first. Each artifact directory is then packed into `out/<name>.tar.gz` in parallel. A draft release is created if one doesn't already exist for the tag, and all tarballs are uploaded with `--clobber`. Files >= 2GiB are flagged since GitHub Releases has a per-asset limit.

### Build

Easiest way to get started is via Nix:

```sh
nix run github:littledivy/promote-release -- --help
```

or run the script directly (requires `gh`, `tar`, and optionally `unzip`):

```sh
chmod +x promote-release.sh
./promote-release.sh --help
```

### Usage

```
promote-release.sh --repo OWNER/REPO --run RUN_ID --tag TAG [--jobs N] [--workdir DIR] [--draft|--publish]
```

```sh
# Download artifacts and create a draft release
./promote-release.sh \
  --repo littledivy/musl-cross-toolchain \
  --run 21479944255 \
  --tag v1.2.5-gcc14.2.0 \
  --jobs 6 \
  --draft

# Same but auto-publish the release
./promote-release.sh \
  --repo littledivy/musl-cross-toolchain \
  --run 21479944255 \
  --tag v1.2.5-gcc14.2.0 \
  --jobs 6 \
  --publish
```

| Flag | Description |
|---|---|
| `--repo` | GitHub repository (`OWNER/REPO`) |
| `--run` | Workflow run ID to download artifacts from |
| `--tag` | Git tag / release name |
| `--jobs` | Parallel jobs for packing and uploading (default: 4) |
| `--workdir` | Working directory (default: temp dir) |
| `--draft` | Leave release as draft (default) |
| `--publish` | Publish the release after uploading |

## License

MIT
