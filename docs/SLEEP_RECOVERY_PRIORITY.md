# WHOOP 5 sleep and recovery: evidence-first implementation track

## Scope and current state

Sleep and recovery are the priority of this personal iOS edition. The starting
point is `design-personnalise` at `6ef61b3d5ad9d877f797fdf971f3d147598a0ac9`.
This change adds an offline input-inventory tool and tests. It does not change
Bluetooth commands, database contents, physiological formulas, or the app UI.
It does not fix sleep detection or demonstrate superiority to WHOOP.

## Findings from the inspected source

- `Packages/WhoopProtocol/Sources/WhoopProtocol/Whoop5RR.swift` already carries
  the WHOOP 5 millisecond unit policy. Do not apply BLE's 1024 conversion again.
- `Packages/WhoopStore/Sources/WhoopStore/Whoop5RRReadPolicy.swift` limits
  scoring transports to channels 5 and 7, with suspect rows excluded. Channel 6
  and unlabelled legacy beats must not be merged into a scored series.
- The store already marks some exact 500 ms beats as suspect using same-second
  heart rate. A 500 ms interval by itself is not evidence of an artefact.
- `SleepStager.swift` explicitly withholds nightly HRV and resting HR for
  HR-only sleep sessions. Removing that guard would make low-evidence data look
  scoreable, not improve recovery accuracy.
- `RecoveryScorer.swift` uses a personal baseline and can return nil during
  calibration. Distinguish a missing nightly signal from an unseeded baseline.
- `Tools/SleepPSG` already compares the shipped stage classifier with PSG labels
  from PhysioNet sleep-accel. Its reference supplies a labelled session window;
  it does not validate session detection. It also lacks RR intervals and uses
  different hardware. Its results do not establish WHOOP 5 field accuracy.
- `docs/WHOOP5_DEEP_DATA.md` distinguishes record decoding from validated
  physiological interpretation. No bulk configuration unlock is needed for this
  audit, and none is supplied here.

## First executable step: inspect one real night

Use a consistent exported SQLite snapshot from NOOP, not a live database and not
a `.noopbak` ZIP. Do not upload private databases to an issue or this repository.
Do not manually copy a live SQLite file without its uncheckpointed data. The
command refuses a non-empty WAL or journal sidecar because immutable reads ignore
such data. Preserve the original export unchanged.

Find the exact device ID using the app's diagnostics/export information. The
example ID below is a placeholder, not an instruction to use a guessed alias.
Use actual bed/wake bounds with an explicit UTC offset; the end is exclusive.

```powershell
python Tools/night_signal_audit.py --db "C:\Data\night.sqlite" --device "EXACT_DEVICE_ID" --start "2026-11-07T23:00:00+01:00" --end "2026-11-08T08:00:00+01:00"
```

The same CLI works on macOS with the relevant local file path and Python command.
The output is a JSON inventory containing counts and relative coverage measures,
not device identifiers, raw biometrics or absolute timestamps. Review any output
before sharing it. There are no network calls and no strap commands.

Interpretation:

| Observation | Next investigation |
|---|---|
| Unknown device in input tables | Confirm selected physical strap and exported device ID first. |
| HR gaps | Inspect sync completeness and recorded history before changing sleep detection. |
| Motion rows missing or sparse | Inspect decoded history and capture provenance; quantify the HR-only fallback separately. |
| Only legacy or channel-6 RR | Inspect source labelling and collection; do not rescale or manufacture intervals. |
| Mostly suspect RR | Inspect the existing rejection reasons and firmware provenance; do not indiscriminately relax filters. |
| Overnight inputs present but recovery absent | Replay baseline seeding, recalibration epoch, and downstream eligibility gates. |

A five-minute bin containing one sample is not five minutes of coverage. Counts
are not a signal-quality certification. Respiration row presence does not prove a
validated waveform. The report intentionally does not produce RMSSD, a recovery
score, sleep phases, or an eligibility judgement.

## Development order after a real-night report

1. **Collection and provenance.** Reproduce missing inputs using existing export
   and diagnostic paths. Fix a proven decoder/storage error with captured evidence
   and synthetic regression tests. Do not introduce guessed byte offsets or new
   sensor configuration writes.
2. **Sleep windows before four-class phases.** Replay the same night with current
   detection. Separate quiet wake, sleep, naps, and fragmentation. Bed/wake diary
   entries describe reported bounds, not PSG-confirmed sleep onset. Preserve manual
   correction and attach provenance to each reference.
3. **HRV and recovery input integrity.** Preserve beat ordering and source identity,
   measure gaps and exclusion rates, then replay nightly aggregation and baseline
   calibration. Keep optional unavailable terms absent and missing scores explicit.
   Do not interpolate an HRV stream from ordinary BPM readings.
4. **Staging experiments.** Reuse SleepPSG before creating another benchmark.
   Record incumbent and candidate over the same labelled epochs, stage confusion
   matrices, per-stage F1, kappa, duration biases, and per-person results. Add a
   separate detection evaluation rather than treating labelled windows as detected
   sessions. For fitted models, keep subjects separate between training and test;
   never randomly split neighbouring epochs. Report hardware/domain differences.
5. **Recovery evaluation.** An official score is a comparison, not ground truth.
   Define independent, prospectively collected outcomes and a held-out evaluation
   before tuning weights. The mere agreement of two proprietary/heuristic scores
   is not evidence that either measures recovery correctly.
6. **Application integration.** Only promote a candidate that improves the chosen
   held-out criteria without breaking coverage, latency, battery or existing users.
   Shared Swift changes need both Apple app builds; protocol/analytics changes need
   Kotlin parity or an explicit platform-limited research scope. BLE changes also
   need real WHOOP 5 verification. No score-formula change is included in this step.

## Completion evidence, not a calendar promise

The initial real-device checkpoint is multiple complete nights from the actual
strap, its firmware identity, a read-only inventory, replayable failures, and
current app build results. More nights and participants are required to evaluate
generalisation. No number of synthetic passing tests replaces a real-device test.

A claim of superiority to WHOOP requires a head-to-head comparison against the
same independent reference, in the same participants and nights, with uncertainty
and failure cases reported. Until then, describe specific measured improvements,
not "better sleep tracking" or a guaranteed better recovery score.

## Verification of this change

```powershell
python -m unittest discover -s Tools/tests -p test_night_signal_audit.py -v
```

Ten synthetic SQLite tests cover read-only behaviour, source separation, suspect
flags, duplicate seconds, sparse bins, device/window filtering, old schemas,
timezone offsets, invalid windows, WAL refusal, and output minimisation. These
are tool tests, not sleep or recovery validation. Xcode and real strap testing
were not available during preparation.
