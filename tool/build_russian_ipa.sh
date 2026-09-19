#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'ERROR: this build script uses macOS/Xcode. Run the OpenStrap Russian IPA GitHub Actions workflow.' >&2
  exit 2
fi
python3 tool/check_russian.py
flutter gen-l10n
flutter test --no-pub test/russian_localization_test.dart test/russian_count_labels_test.dart test/russian_metric_notes_test.dart test/russian_metric_specs_test.dart test/russian_screens_test.dart test/widget_russian_locale_test.dart test/widget_service_sentinels_test.dart test/battery_audit_policy_test.dart test/absence_reason_test.dart test/wear_gap_reason_test.dart --reporter=expanded --concurrency=1 --timeout=60s
flutter build ios --release --no-codesign --dart-define-from-file=.env
APP="$PWD/build/ios/iphoneos/Runner.app"
[[ -f "$APP/Info.plist" && -f "$APP/Runner" ]]
# Same sideload limitation as upstream: the Watch companion cannot be re-signed
# reliably with a free Apple ID. Remove it from BUILD OUTPUT only.
python3 - "$APP" <<'PY'
import pathlib, shutil, sys
app=pathlib.Path(sys.argv[1]).resolve()
watch=(app/'Watch').resolve()
assert watch.parent == app and app.name == 'Runner.app'
if watch.exists(): shutil.rmtree(watch)
PY
STAGING=$(mktemp -d "$PWD/build/ru-ipa.XXXXXX")
mkdir -p "$STAGING/Payload"
ditto "$APP" "$STAGING/Payload/Runner.app"
mkdir -p dist
IPA="$PWD/dist/OpenStrap-RU-0.9.29-unsigned.ipa"
(cd "$STAGING" && zip -qry -y "$STAGING/fresh.ipa" Payload)
mv "$STAGING/fresh.ipa" "$IPA"
python3 tool/verify_russian_ipa.py "$IPA"
shasum -a 256 "$IPA" > "$IPA.sha256"
echo "IPA_CREATED=$IPA"
