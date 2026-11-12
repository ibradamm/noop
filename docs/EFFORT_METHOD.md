# Independent NOOP effort on 0–21

This describes the existing mathematical engine, not a validation of physiological load.
Source of truth: [Packages/StrandAnalytics/Sources/StrandAnalytics/StrainScorer.swift](../Packages/StrandAnalytics/Sources/StrandAnalytics/StrainScorer.swift) and its twin
[android/app/src/main/java/com/noop/analytics/StrainScorer.kt](../android/app/src/main/java/com/noop/analytics/StrainScorer.kt). iOS display conversion is in
[Strand/Data/Units.swift](../Strand/Data/Units.swift); stored values remain on the upstream 0–100 axis for backup compatibility.

## Formula and inputs

For heart rate HR, resting HR R and maximum HR M, reserve is M−R. The intensity fraction is
`x = clamp((HR−R)/(M−R), 0, 1)`. HR is sensor-reported/filtered input, not raw ECG. R and M can be
measured estimates or profile/formula fallbacks; defaults are assumptions and must not be described
as personal measurements. The engine's HRmax helper uses an observed high percentile with sufficient
samples, an age-based Tanaka estimate, or a default fallback. This is not a measured maximum test.

The default recipe uses Edwards-style weights `0,1,2,3,4,5` at 50/60/70/80/90% **HR reserve**.
This differs from Edwards' published HRmax zones. For sample duration `dt` in minutes,
`T = sum(weight(x) * dt)`. The default denominator is `D = 7201` (24 h × 60 × maximum weight + 1).

The optional Banister recipe uses `r(x) = x * a * exp(b*x)` with published paired coefficients
`(a,b)=(0.64,1.92)` for men and `(0.86,1.67)` for women. NOOP subtracts its documented sedentary
baseline rate `r(0.10)` per sample, floors the remainder at zero, then integrates.
Its denominator is `D = 1440 * (r(1) − r(0.10)) + 1`. The baseline subtraction is NOOP's
convention, not a validated separation of exercise from ordinary living.

Stored score is `round_2dp(100 * ln(T+1) / ln(D))`. The personal iOS view displays
`stored * 21 / 100` to one decimal. This linear conversion is an axis choice, not a reproduction
of WHOOP's proprietary formula. Daily load is calculated over its own HR window; session scores
are not added. The logarithmic map is nonlinear.

Integration uses the next timestamp gap, capped at two minutes, and repeats the final gap.
One-sample/coincident-time fallback is one second. These conventions approximate intervals;
they do not observe what happened between samples. The current scorer accepts a dense sample count
or a sparse sample count plus elapsed span; neither certifies full-day coverage. The engine may
also apply existing activity/steps/energy floors outside `StrainScorer` (see `AnalyticsEngine.swift`).
The dashboard reads the actual computed daily output, not a fresh formula reimplemented in UI.

## Refusal and calibration policy

The scorer returns nil/null for insufficient inputs, M≤R, invalid numeric configuration or
nonpositive HR values. This batch adds the invalid-input refusal; it does not relax existing gates
or alter the valid-input weights. A genuine observed calm window may score zero. A refused window
must not be described as zero exertion. The home additionally refuses nonfinite/out-of-domain stored
scores rather than clipping them to a plausible 0–21 value.

The denominator is a mathematical ceiling convention, not a physiological calibration against
independent reference data. The repository contains denominator-fitting/WHOOP comparison helpers;
they are not used by this batch. Do not adjust weights or denominator just to match commercial
scores. Before any future calibration, freeze the intended endpoint, reference, training subjects,
held-out subjects and acceptance criteria as described in the validation protocol.

There is no validated mapping from this number to muscular work, fatigue, readiness, calories or
next-day performance. Sparse HR misses peaks; wrist motion can contaminate HR; profile errors change
zones; strength training is incompletely captured. A numerical output is an estimate of the recorded
cardiovascular evidence, not proof of complete daily effort.
