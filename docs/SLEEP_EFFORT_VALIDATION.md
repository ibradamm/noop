# Validation protocol: freeze before tuning

Version 1, 2026-11-12. Status: prepared; **no owner data collected or evaluated**.
Software correctness, hardware operation and physiological precision are separate gates.

## Common study contract

Record commit, algorithm/settings, device family, firmware, wear site, profile parameter source,
reference device/version, sampling/clock uncertainty, timezone/UTC offset and any manual corrections.
Keep originals and correction history locally, with file hashes; never commit private recordings.
Use a pseudonymous participant/session key. Split by **participant** (and by nights/sessions for a
personal pilot), not neighboring epochs. Freeze a calibration set and a held-out evaluation set
before adjusting algorithms. Repeatedly inspecting a holdout makes it development data: replace it
before any final claim. Stratify by person, night, wear quality, naps, fragmented sleep and activity.

Reject unverifiable source/unit/clock identity, corrupt values, impossible chronology and unknown
device mixing. Missing periods remain missing. Report refusal/coverage as well as error so rejecting
difficult segments cannot manufacture better accuracy. Do not interpolate through absent HR or RR.
Use paired per-person/night/session results and participant-clustered 95% confidence intervals when
the sample size permits; a single person's repeated nights support only that person's pilot.

## Measures, references and acceptance

| Measure | Independent reference and reproducible comparison | Acceptance before promotion |
|---|---|---|
| Frame/units/storage | Synthetic CRC-valid/invalid frames and SQLite fixtures; exact epoch-second, millisecond, SI and source assertions; backup round trip; duplicate and conflict fixtures. | Every deterministic assertion passes; zero silent coercion, dropped correction or cross-device merge. This is software correctness only. |
| HR and zones | Simultaneously record a documented electrical reference, e.g. Polar H10 with signal-quality/artefact records, ideally checked against ECG. Use resting, walking, running, cycling, intervals and resistance sessions. Synchronize clocks before recording; freeze any measured offset using calibration only. Pair at the actual reference cadence; at 1 Hz use nearest sample within 0.5 s, no gap filling. | Publish MAE, signed bias, absolute-error percentiles, Bland–Altman limits, valid-pair fraction, unpaired time, per-activity results and zone confusion. A candidate must improve held-out paired MAE with the CI for candidate-minus-incumbent below zero, without reducing coverage. This is a relative development gate, not an absolute accuracy label. An absolute BPM claim needs a preregistered use-specific error budget including reference uncertainty and personal zone boundaries. |
| RR / RMSSD / resting HR | Simultaneous ECG-derived or appropriately validated electrical beat intervals, independently artefact-labelled. Preserve transport, order, suspect flags and uninterrupted windows; compare matched windows only. | No HR→RR reconstruction, channel pooling or scaling guesses. Report timing/unit errors, exclusion rate, bias/limits for RR and RMSSD, and per-window failure rate. Select an absolute HRV error budget for the intended use before tuning; none has been established here. |
| Bed, attempt, rise and reported wake | Prospective diary with separate timestamps and annotation resolution. Record lights-out/attempt, reported sleep onset if known, final wake and out-of-bed separately, including naps and confidence. Compare detected bounds to each relevant annotation, retaining edits. | No invented latency: `estimated onset − credible attempt start` only when both exist and chronology is valid. Diary agreement supports agreement with reports; quiet wake, true sleep onset, awakenings, sleep duration and phases require stronger references. Report signed/absolute boundary errors and disagreement relative to diary precision. |
| Sleep detection / naps / TST / WASO / efficiency | Simultaneous PSG with scored wake/sleep over the **full observation interval**, not only an already-labelled night. Evaluate missed/extra sessions, onset/offset, TST, WASO and efficiency on held-out people and fragmented nights. | Publish detection precision/recall, wake specificity, boundary errors and duration bias/limits. Candidate improves paired held-out error and does not worsen missed/false sessions or coverage. Absolute targets must be locked for the intended context with sleep expertise; none is claimed from the software tests. |
| Light/deep/REM and deep+REM | PSG epochs scored independently of wearable output; epoch mapping and stage vocabulary frozen. Use `Tools/SleepPSG` for transferable method experiments, plus simultaneous WHOOP 5 recordings before target-hardware claims. | Experimental until target-hardware evaluation exists. Report confusion matrix, macro/per-stage F1, kappa, wake specificity, per-person results and stage-duration bias/limits. Candidate must improve held-out macro-F1 without worsening wake specificity, duration error or coverage; report uncertainty. No single kappa threshold certifies consumer sleep accuracy. |
| Regularity / estimated need / debt | Verify deterministic time aggregation with DST/travel/fragmentation fixtures. For physiological need/debt, prospectively define an independent endpoint and observation period; a user goal is not physiological need. | Exact aggregation tests can pass independently. Need/debt remain labelled estimates; no physiological accuracy claim before an endpoint and acceptance budget are preregistered. |
| Nocturnal stress | No accepted reference endpoint has been established in this project. First define the construct, signals and independent protocol; PSG sleep stages or WHOOP's stress number alone do not validate it. | Remains experimental/unavailable. No promotion or downstream readiness gate. |
| Effort 0–21 / zone minutes | Synthetic known-intensity/time streams for formula tests; simultaneous reference HR for time-in-zone trials; independent training-load endpoint required for a load-accuracy claim. Evaluate session and full-day windows separately. | Exact formula/axis/source tests pass; no summing session scores, silent WHOOP substitution or absent-as-zero. Report sample gaps, credited versus observed duration, profile assumptions and reference zone-time error. The score itself has no independent physiological scale validation yet. |
| Steps / kcal / VO₂ max | Observed/video-counted steps across speeds/wear states; indirect calorimetry for energy; laboratory CPET for VO₂ max. Vendor/Health imports retain their original source. | Report count error, kcal bias/limits and VO₂ bias/limits across held-out people and contexts. Freeze use-specific tolerances with reference uncertainty before tuning. HR-only energy is never described as precise. |
| Strength logs / muscular load | Exact exercise/set/rep/weight persistence fixtures, then hardware/UI trial. A muscular-load model needs a documented independent endpoint beyond tonnage. | Log correctness is separate from load-model validity; no invented muscular score. |
| Alarm / weekdays | Verify known reversible command, readback, actual vibration at scheduled time, cancellation, weekdays, reconnect, app suspended/closed, timezone/DST change and strap-clock behavior on the owner's WHOOP 5. Keep a separate dependable alarm during trials. | Record each scheduled/actual/cancelled event and deviation; all planned scenarios must operate before saying the function works on this strap. Readback or successful BLE write alone is insufficient. No recovery-based wake mode. |
| Import / corrections / sources | Private repeated/overlapping exports, two devices, offset/DST transitions, unit boundaries and conflicting manual corrections. Verify exact source-specific round trips and user-visible conflict handling. | No silent score blending or replacement of edited history; duplicate import is idempotent where promised. Preserve unavailable values, original units/provenance and a correction trace. |

The relative comparison gates above are deliberate development criteria: they avoid inventing a
universal medical or consumer error threshold without an intended-use budget. They do not authorize
an “accurate” label. No weights were tuned in this batch. Failed or insufficient-confidence comparisons
remain inconclusive rather than successes.

## Research references and transfer limits

- [Miller et al., 2020, WHOOP versus PSG](https://pubmed.ncbi.nlm.nih.gov/32713257/) reports agreement
  with a PSG reference, including limited wake specificity. It predates WHOOP 5 and does not evaluate
  NOOP's independent detector. Its numbers cannot certify this hardware/software combination.
- [Schyvens et al., 2025, six wearables versus PSG](https://pubmed.ncbi.nlm.nih.gov/40303381/)
  includes WHOOP **4.0**, not a NOOP-on-WHOOP-5 trial. It supports using stage-specific and
  wake/sleep metrics rather than a single sleep-duration comparison.
- [Schaffarczyk et al., 2022, Polar H10 versus ECG](https://pubmed.ncbi.nlm.nih.gov/36081005/)
  studies resting and incremental-exercise interval measurements. It documents a possible reference;
  it does not remove artefact checks or establish accuracy for every sport/person/setup.
- `Tools/SleepPSG/README.md` documents the PhysioNet sleep-accel benchmark and attribution. Its
  different wearable/sampling, no target RR stream and supplied session bounds limit transfer. A
  passing staging benchmark cannot validate detection of the night itself or WHOOP 5 field accuracy.

Sources consulted on 2026-11-12. WHOOP outputs are commercial comparisons, never the independent
reference. No claim of parity or superiority is made.

## Local collection record

Copy [validation/session-log-template.csv](validation/session-log-template.csv) to a private folder
outside the repository. Fill timestamps with offsets and leave unknown cells empty, never zero.
The template contains column names only. Store raw recordings/snapshots and result files outside git.
Record each run in the evidence ledger only with aggregate, non-identifying software-test results.
