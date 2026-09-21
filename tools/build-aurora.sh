#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
architecture="${1:-all}"
if (($#)); then shift; fi
case "$architecture" in
  all) targets=(aurora-arm64 aurora-arm) ;;
  aarch64|arm64) targets=(aurora-arm64) ;;
  armv7hl|arm) targets=(aurora-arm) ;;
  *) echo "Usage: $0 [all|aarch64|armv7hl] [flutter build options...]" >&2; exit 2 ;;
esac

if [[ "$(id -u)" == 0 ]]; then
  echo 'Run as the SDK owner, not root (see docs/AURORA.md).' >&2
  exit 1
fi

flutter_bin="${FLUTTER_AURORA_BIN:-/home/aurora-build/flutter_aurora_linux/bin/flutter}"
psdk_dir="${AURORA_PSDK_DIR:-/home/aurora-build/AuroraPlatformSDK/sdks/aurora_psdk}"
[[ -x "$flutter_bin" && -x "$psdk_dir/sdk-chroot" ]] || {
  echo 'Set FLUTTER_AURORA_BIN and AURORA_PSDK_DIR to installed SDK paths.' >&2
  exit 1
}

cd "$project_root"
output_dir="$project_root/dist/aurora"
mkdir -p "$output_dir/logs"
"$flutter_bin" pub get --enforce-lockfile
"$flutter_bin" analyze lib --no-pub --no-fatal-infos 2>&1 | tee "$output_dir/logs/analyze.log"

shopt -s nullglob
for target in "${targets[@]}"; do
  "$flutter_bin" build aurora --release --no-pub \
    --psdk-dir "$psdk_dir" --target-platform "$target" "$@" \
    2>&1 | tee "$output_dir/logs/build-$target.log"
  packages=("$project_root"/build/aurora/psdk_5.2.1/"$target"/release/RPMS/*.rpm)
  if ((${#packages[@]} == 0)); then
    echo "No RPM produced for $target (expected Platform SDK 5.2.1)." >&2
    exit 1
  fi
  for package in "${packages[@]}"; do
    result="$output_dir/$(basename -- "$package")"
    cp -- "$package" "$result"
    "$psdk_dir/sdk-chroot" rpm-validator --profile regular --color never "$result" \
      2>&1 | tee "$output_dir/logs/validate-$(basename -- "$package").log"
  done
done

(cd "$output_dir" && sha256sum ./*.rpm > SHA256SUMS)
echo "Release RPMs and validation logs: $output_dir"
