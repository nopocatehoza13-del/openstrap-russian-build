# Experimental intraday HR activation v1

This is an independent, transparent heuristic, NOT WHOOP Stress and NOT a validated medical or psychological-stress measure. The broad idea of relative HR + motion gating was reviewed in the pinned NOOP audit; no NOOP source was copied. No new sensor commands, vendor service calls, RR-derived values, or changes to the original nightly Baevsky index.

## Inputs and model
- Canonical persisted 1 Hz HR and gravity; explicit HR-invalid flags, off-wrist and charging spans reject samples.
- Motion is the existing OpenStrap 1 Hz orientation-change proxy (>5 degree z-angle change across adjacent seconds). No contiguous acceleration pair means unknown, never stillness.
- >=30 distinct co-observed HR+motion seconds per minute. Plausible HR 25–230, no imputation. >=4 covered minutes per non-overlapping 5-minute plotted bucket.
- Reference: lower quartile of non-sleep, non-workout, low-movement minute HR within the SAME local calendar day. >=60 eligible minutes spread over >=3 distinct clock-duration hours. This is a day-relative reference, NOT a longitudinal personal baseline.
- Scale = max(5 bpm, HR interquartile range / 1.349). Score = 3 / (1 + exp(-(minute HR - reference) / scale)). The 5 bpm floor and thresholds are model assumptions, NOT measured physiological constants or evidence of equivalence to WHOOP.
- Bands <1 / 1–2 / >=2. Time summaries sum actually covered seconds, not estimated entire minutes or overlapping windows. Points and averages are duration-weighted; gaps/future/uncovered scopes stay null.

## Categories and corrections
All: includes physical activation. Non-activity: excludes recorded exercise, observed movement >=20% of seconds, known sleep windows, and the first 30 minutes after activity while HR stays >reference+8 bpm. Sleep: canonical main/nap windows excluding conflicting activity; this is sleep-window attribution, not a new sleep-stage detector. Minute midpoint determines category; boundaries resolve only to one minute. Manual corrections may change scores/reference because they change eligible samples.

Local calendar start/end are passed explicitly (23/25 hour DST supported). Data are stored in day_result.intraday_stress, model version 1, kAlgoVersion 97. Compact measured minute features outlive raw retention. A single pure function handles derivation and off-isolate presentation re-projection against current overlapping workout intervals (including workouts started before midnight and live sessions). Existing metric_series stress and all nightly scores are untouched. No stress notifications.

## Limitations
Movement and wrist PPG can be noisy; low 1 Hz movement cannot rule out all physical load. Illness, caffeine, posture and many other factors can affect HR. Absence of sleep labels does not prove wakefulness; 'non-activity' means outside KNOWN intervals. Day-relative scores can change with later sync and may normalize an entirely elevated day; do not compare them as a clinical long-term trend. Ordinary WHOOP summary CSV has no necessary second-by-second history. Old days whose raw history was already pruned cannot gain this metric retroactively.

## Validation in this build
Synthetic quality/coverage/segmentation/DST/idempotence tests, database round-trip and manual correction tests, native widget/golden checks. These verify software behavior only. No WHOOP 5/MG hardware or clinical validation has been performed.
