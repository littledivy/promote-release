#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
promote-release.sh --repo OWNER/REPO --run RUN_ID --tag TAG [--jobs N] [--workdir DIR] [--draft|--publish]

Requires: gh, tar, unzip (optional), xargs
Notes: GitHub Release assets must be < 2GiB per file.

Examples:
  ./promote-release.sh --repo littledivy/musl-cross-toolchain --run 21479944255 --tag v1.2.5-gcc14.2.0 --jobs 6 --draft
  ./promote-release.sh --repo littledivy/musl-cross-toolchain --run 21479944255 --tag v1.2.5-gcc14.2.0 --jobs 4 --publish
EOF
}

REPO=""
RUN_ID=""
TAG=""
JOBS=4
WORKDIR=""
MODE="draft" # draft|publish

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --run) RUN_ID="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --workdir) WORKDIR="$2"; shift 2 ;;
    --draft) MODE="draft"; shift ;;
    --publish) MODE="publish"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${REPO}" || -z "${RUN_ID}" || -z "${TAG}" ]]; then
  usage
  exit 1
fi

command -v gh >/dev/null || { echo "Missing dependency: gh"; exit 1; }
command -v tar >/dev/null || { echo "Missing dependency: tar"; exit 1; }

if [[ -z "${WORKDIR}" ]]; then
  WORKDIR="$(mktemp -d)"
fi

echo "==> Workdir: $WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> Downloading artifacts from run $RUN_ID ($REPO)"
mkdir -p artifacts
cd artifacts
gh run download "$RUN_ID" -R "$REPO"
cd ..

# If downloads are zip files (some setups), unzip them into directories
shopt -s nullglob
zips=(artifacts/*.zip)
if (( ${#zips[@]} > 0 )); then
  command -v unzip >/dev/null || { echo "Have zip artifacts but missing dependency: unzip"; exit 1; }
  echo "==> Found ${#zips[@]} zip(s); extracting..."
  mkdir -p extracted
  for z in "${zips[@]}"; do
    name="$(basename "$z" .zip)"
    mkdir -p "extracted/$name"
    unzip -q "$z" -d "extracted/$name"
  done
  SRC="extracted"
else
  # gh run download typically creates directories directly
  SRC="artifacts"
fi

echo "==> Packing to tar.gz (parallel: $JOBS)"
mkdir -p out
cd "$SRC"

# pack each top-level directory except out/
ls -1d */ 2>/dev/null | grep -v '^out/' | \
  xargs -I{} -P "$JOBS" bash -lc '
    set -euo pipefail
    d="{}"; name="${d%/}"
    echo "Packing $name"
    tar -C "$name" -czf "../out/$name.tar.gz" .
  '

cd ..

echo "==> Checking for files >= 2GiB (GitHub Release per-asset limit)"
# portable file size check (macOS stat -f%z, Linux stat -c%s)
too_big=0
for f in out/*.tar.gz; do
  [[ -e "$f" ]] || continue
  size="$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f")"
  if (( size >= 2147483648 )); then
    echo "WARN: $(basename "$f") is >= 2GiB ($(ls -lh "$f" | awk "{print \$5}")) and will FAIL to upload."
    too_big=1
  fi
done
if (( too_big == 1 )); then
  echo "Tip: split big tarballs, e.g.: split -b 1900m file.tar.gz file.tar.gz.part-"
fi

echo "==> Ensuring release exists: $TAG"
if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" -R "$REPO" --draft --title "$TAG" --notes ""
fi

echo "==> Uploading assets (parallel: $JOBS)"
ls -1 out/*.tar.gz | \
  xargs -I{} -P "$JOBS" bash -lc '
    set -euo pipefail
    f="{}"
    echo "Uploading $(basename "$f")"
    gh release upload "'"$TAG"'" "$f" -R "'"$REPO"'" --clobber
  '

if [[ "$MODE" == "publish" ]]; then
  echo "==> Publishing release $TAG"
  gh release edit "$TAG" -R "$REPO" --draft=false
else
  echo "==> Left release as draft (use --publish to publish automatically)"
fi

echo "==> Done."
echo "Artifacts: $WORKDIR/out"
