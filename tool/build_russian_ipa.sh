#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'ERROR: this build script uses macOS/Xcode. Run the OpenStrap Russian IPA GitHub Actions workflow.' >&2
  exit 2
fi
python3 tool/check_russian.py
flutter gen-l10n
flutter test --no-pub test/russian_runtime_screens_test.dart test/russian_observations_extra_test.dart test/russian_activity_extra_test.dart test/russian_core_extra_test.dart test/profile_russian_extra_test.dart test/notification_russian_copy_test.dart test/native_russian_localization_test.dart test/russian_localization_test.dart test/russian_count_labels_test.dart test/russian_metric_notes_test.dart test/russian_metric_specs_test.dart test/russian_screens_test.dart test/widget_russian_locale_test.dart test/widget_service_sentinels_test.dart test/battery_audit_policy_test.dart test/absence_reason_test.dart test/wear_gap_reason_test.dart --reporter=expanded --concurrency=1 --timeout=60s
flutter analyze --no-pub lib/ui2/familiar lib/data/imported_vitals.dart lib/data/local_repository_impl.dart lib/app.dart lib/ui2/app_shell.dart lib/ui2/screens/workout_screen.dart lib/ui2/screens/readiness_detail.dart lib/ui2/activity/day_strain.dart packages/personal_analytics lib/compute/intraday_stress_bridge.dart lib/compute/derivation_engine.dart
flutter test --no-pub test/intraday_stress_test.dart test/intraday_stress_repository_test.dart test/intraday_stress_ui_test.dart test/db_serve_version_and_reads_test.dart test/familiar_age_test.dart test/familiar_ui_test.dart test/familiar_import_test.dart test/manual_session_test.dart test/import_data_safety_test.dart test/ui2_sleep_detail_test.dart test/edit_profile_import_test.dart test/sleep_profile_policy_test.dart test/ui2_contrast_test.dart test/ui2_tokens_test.dart --reporter=expanded --concurrency=1 --timeout=120s
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
IPA="$PWD/dist/OpenStrap-Familiar-RU-0.9.29-v6-unsigned.ipa"
(cd "$STAGING" && zip -qry -y "$STAGING/fresh.ipa" Payload)
mv "$STAGING/fresh.ipa" "$IPA"
python3 tool/verify_russian_ipa.py "$IPA"
shasum -a 256 "$IPA" > "$IPA.sha256"
echo "IPA_CREATED=$IPA"
