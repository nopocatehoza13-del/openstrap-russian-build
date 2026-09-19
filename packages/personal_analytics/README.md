# Experimental body-age indicator

Independent expression of the publicly described five-factor NOOP arithmetic:
https://github.com/ryanbr/noop/blob/158a05ac58fac07ed1eb17e6e5a1077e4da6aa07/Packages/StrandAnalytics/Sources/StrandAnalytics/VitalityEngine.swift

No source files, assets or tests copied from that project. This model is not WHOOP
Age, not validated medicine and not an estimate of life expectancy. Coefficients
are heuristics. Do not interpret low resting pulse as invariably healthier.

Our additional gates: ages 20–90; valid finite measurements; three distinct
measured quantities, each on three distinct days within seven calendar days;
sleep variability does not count as an independent quantity. Missing values are
excluded, not filled. No age is returned after a stale/no-data week. Display the
window and sample counts. Adding a factor can change the result independently of
physiology. Sleep variability uses duration, not sleep timing or SRI.

Calculated for display from saved chart series; no metric persistence, no schema,
BLE or canonical derivation changes. Existing kAlgoVersion is therefore unchanged.
