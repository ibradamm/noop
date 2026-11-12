# Personal iOS edition: sleep and effort

For subsequent legacy-route/Watch/export corrections and actual Windows/Linux/native results,
see [the batch validation record](SLEEP_EFFORT_BATCH_VALIDATION.md). It supersedes the initial
remaining-work list below where explicitly corrected.

Audit date: 2026-11-12. This is an implementation inventory, not a precision certificate.
The product has two pillars: sleep and an independent NOOP effort calculation displayed on
0–21. There is no replacement readiness score. HRV and resting HR remain information.

## Repository evidence

- The working tree was clean on `design-personnalise` at `6ef61b3d`.
  That commit changed only [StrandiOS/App/RootTabView.swift](../StrandiOS/App/RootTabView.swift): three tabs and selected routes.
  It did not implement a two-circle home, remove the recovery calculations, or validate data.
- `origin` was fetched. `main` is `2a1de760`; the inspected remote audit branch is
  `sleep-recovery-input-audit` at `5e89bec6`.
- The audit branch contains only [Tools/night_signal_audit.py](../Tools/night_signal_audit.py), its ten synthetic tests,
  and `docs/SLEEP_RECOVERY_PRIORITY.md`. Its recovery roadmap is superseded here.
  Only the read-only tool and tests were reused, then strengthened. No branch was merged.
- Work is isolated on `sleep-effort-reliability`, based on `design-personnalise`.
  No reset, main merge, firmware change, release, or health-data upload was performed.

## End-to-end input audit

| Layer | Evidence and interpretation |
|---|---|
| Acquisition | [Strand/BLE/BLEManager.swift](../Strand/BLE/BLEManager.swift), [Strand/BLE/FrameRouter.swift](../Strand/BLE/FrameRouter.swift) (`handle`): CoreBluetooth link and full-frame checksum/length gate. [Strand/Collect/Collector.swift](../Strand/Collect/Collector.swift) records live HR and labelled RR. Connection and offload success still require this owner's hardware. |
| Decode | [Packages/WhoopProtocol/Sources/WhoopProtocol/Whoop5RR.swift](../Packages/WhoopProtocol/Sources/WhoopProtocol/Whoop5RR.swift): WHOOP 5 interval words are milliseconds, including its nonstandard standard-HR transport. Do not apply 1024 conversion again. `docs/PROTOCOL_WHOOP5.md` and `docs/PROTOCOL_SENSORS.md` distinguish decoded fields from physiological interpretations. |
| Storage | [Packages/WhoopStore/Sources/WhoopStore/StreamStore.swift](../Packages/WhoopStore/Sources/WhoopStore/StreamStore.swift) and `Whoop5RRReadPolicy.swift`: device-scoped streams, labelled sources, suspect flags; WHOOP 5 scoring chooses one transport from channels 5/7. Channel 6 and legacy unlabelled rows are not substitutes. The same-second HR rule flags some 500 ms fill candidates; 500 ms alone is not a rejection criterion. No RR rule was relaxed. |
| Aggregation | [Packages/StrandAnalytics/Sources/StrandAnalytics/AnalyticsEngine.swift](../Packages/StrandAnalytics/Sources/StrandAnalytics/AnalyticsEngine.swift) (`analyzeDay`) and `SleepStager.swift`: missing sessions can yield nil sleep duration. The HR-only fallback withholds nightly HRV/RHR rather than manufacturing them. `HRVAnalyzer.swift` applies additional interval/window gates; input presence does not establish eligibility. |
| Resolution | [Strand/Data/Repository.swift](../Strand/Data/Repository.swift) (`sourceCandidates`, `resolvedSeries`, `resolvedRows`) ordinarily prefers imported WHOOP points to computed ones and fills missing days from other namespaces. That behavior can hide which score a dashboard is showing. The new home explicitly reads the active device's `-noop` namespace and shows a commercial comparison separately. It does not silently borrow another device's historical namespace. |
| Display | [StrandiOS/Screens/SleepEffortHomeView.swift](../StrandiOS/Screens/SleepEffortHomeView.swift): two circles, optional values, duration `hours : minutes`, 0–21 effort, previous-day comparison and user-selected goals. No demo constants, readiness verdict, baseline carry, or import-as-NOOP fallback. |

The structural claims above are source findings. Upstream comments describing field captures are
not fresh measurements on this owner's WHOOP 5.0.

## WHOOP 5.0 capabilities and limits

The tree supports live and historical HR, labelled RR transports, motion records, temperature
records, battery/link information and a vendor daily step count. Availability depends on firmware,
wear state, completed history transfer and transport. Decodable records are not a guarantee of
continuous coverage or accurate physiology. See `docs/WHOOP5_DEEP_DATA.md` for optical/IMU record
boundaries: raw optical fields do not establish calibrated SpO₂ or a respiratory waveform.
Alarm commands exist, with upstream WHOOP 4.0 evidence; this owner's WHOOP 5 vibration, clock
retention and weekday behavior have not been tested. No new BLE command was added.

## Feature inventory

“Implemented” means code exists, not that it is correct on this device. In this session **none**
of the following physiological features was validated on hardware or in precision.

| Requested feature | Implementation and provenance | Device validation | Precision validation |
|---|---|---|---|
| Nights, naps, onset/wake and interruptions | Partial algorithmic estimates: `SleepStager.swift`, `SleepStagerV2.swift`, [Strand/Screens/SleepView.swift](../Strand/Screens/SleepView.swift). Quiet wake and sparse input remain ambiguous. | Pending | Pending |
| Bedtime, time in bed, sleep latency | Partial imported/annotated windows; detected sleep start is not a measured attempt-to-sleep start. Independent local latency is unavailable without a credible attempt timestamp. | Pending | Blocked by reference/annotations |
| Asleep duration, wake time, efficiency | Implemented estimates/derived ratios when inputs exist: `AnalyticsEngine.swift`, `SleepView.swift`; not interchangeable with time in bed. | Pending | Pending |
| Regularity, estimated need and debt | Implemented estimates: `AnalyticsEngine.swift` (`Rest`), `SleepDebt.swift`, [Strand/Screens/SleepModel.swift](../Strand/Screens/SleepModel.swift); thresholds and personal calibration need evaluation. | Pending | Pending |
| Light/deep/REM and deep+REM total | Experimental classification/derived sum: `SleepStagerV2.swift`, `SleepView.swift`; imported labels remain vendor outputs. | Pending | Blocked by matched PSG on target hardware |
| Nocturnal physiological stress | Partial stress estimators exist ([Strand/Screens/StressView.swift](../Strand/Screens/StressView.swift), `DaytimeStress.swift`); no established nocturnal reference or target-hardware validation. | Pending | Blocked; experimental/unavailable |
| Sleep history and manual night/nap correction | Implemented UI and durable edit paths in `SleepView.swift` and `Repository.swift`; edits re-stage available signals, not new ground truth. | Pending | Not a precision certification |
| Alarm and weekday scheduling | Implemented command/settings paths: `SmartAlarmView.swift`, `BehaviorStore.swift`, [Strand/BLE/Commands.swift](../Strand/BLE/Commands.swift); WHOOP 5 operation unverified. UI explicitly labels the experiment. | Blocked by strap trial | Not applicable to sleep staging |
| HR, personalized zones and curves | Implemented sensor-reported/filtered HR and profile-based zones: `LiveView.swift`, `WorkoutDetailView.swift`, `WorkoutZones.swift`. | Pending | Needs electrical reference |
| Session/day effort, live/manual recording | Implemented estimate: `StrainScorer.swift`, `WorkoutsView.swift`, `LiveWorkoutView.swift`, `ManualWorkoutSheet.swift`. Stored 0–100 axis is displayed as 0–21. | Pending | No validated equivalence to WHOOP or physical work |
| Automatic workout confirmation/correction | Partial: `AutoWorkoutDetector.swift`, `AutoWorkoutCard.swift`, workout edit screens. False positives and missed sessions need stratified trials. | Pending | Pending |
| Session/day/week zone time, history, comparison | Partial: `WorkoutZones.swift`, `WorkoutDetailView.swift`, `TrendsView.swift`, `CompareView.swift`. Credited sample time must not be presented as observed wear time. | Pending | Pending |
| Goals independent of recovery | New personal home stores explicit user sleep/effort goals; no physiological need is inferred. Recovery-based target notification is disabled on iOS even for persisted opt-ins. | Pending UI trial | Not a physiological claim |
| Exercises, sets, reps and weights | Existing `LiftLogView.swift`, `LiftSessionView.swift`, [Packages/WhoopStore/Sources/WhoopStore/LiftLogStore.swift](../Packages/WhoopStore/Sources/WhoopStore/LiftLogStore.swift), [Packages/StrandAnalytics/Sources/StrandAnalytics/LiftMetrics.swift](../Packages/StrandAnalytics/Sources/StrandAnalytics/LiftMetrics.swift). A validated muscular-load score is not established. | Pending | Muscular load blocked by method/reference |
| Steps, calories, VO₂ max | Kept: sensor/vendor steps, motion estimates, imported activity energy and independent VO₂ estimates have different origins (`MetricCatalog.swift`, `WorkoutDetector.swift` (`Calories`), `StepsEstimateEngine.swift`). HR-only kcal is approximate, not precise energy expenditure. | Pending | Needs counts/calorimetry/CPET respectively |
| WHOOP import | Existing importer normalizes units including 0–21 → stored 0–100 ([Strand/Data/WhoopImporter.swift](../Strand/Data/WhoopImporter.swift), [Packages/StrandImport/Sources/StrandImport/WhoopExportImporter.swift](../Packages/StrandImport/Sources/StrandImport/WhoopExportImporter.swift)). New home keeps commercial effort separate. Existing duplicate/conflict behavior still needs real-export integration trials. | Pending | Vendor scores are comparisons only |

## Changes in this first batch

1. Read-only night inventory now excludes structurally invalid values from timestamp coverage;
   reports duplicate/conflicting HR seconds, all three motion axes, malformed timestamps and RR
   values; keeps transports separate; redacts malformed channel payloads. Counts are not scores.
2. Swift and Kotlin effort scorers refuse nonfinite configuration, nonpositive resting HR, invalid
   log-map domains and nonpositive HR samples. Such inputs formerly could become zero/nonfinite
   outputs. Both recipes share the refusal; valid recipes and RR gates are unchanged.
3. iOS home uses sleep/effort only. Local and imported effort are separate; comparisons require both
   days. Missing values remain dashes. Goals are user choices, initially unset.
4. iOS removes recovery contributors, recovery catalog choices, recovery trend/digest/PDF entries,
   recovery settings, the recovery-derived notification and its queued/delivered request, recovery
   widget rings and Live Activity values. Coach is disabled before background initialization;
   the Coach widget/shortcut and Journal launch entries are removed. Old Coach shortcuts do not run
   a provider request. The iOS scoring guide explains independent effort without recovery.
5. Shared domain math remains portable; the input refusal has a Kotlin twin. Personal product/UI
   changes are deliberately iOS-only; macOS and Android retain their upstream product layout.
6. The translation gate now uses POSIX repository paths for catalog allowance lookups on Windows,
   matching its existing allowance files without increasing or removing any quality budget.

## Remaining risks and prioritized work

1. **Build gate before installation:** compile `NOOPiOS` and `Strand`, run native suites. Windows here
   has no Swift/Xcode/JDK; Docker has no running engine. Source inspection and Python tests cannot
   prove SwiftUI type correctness or complete navigation coverage.
2. **Complete the removal audit on an iPhone:** traverse onboarding/help, stale deep links, sharing,
   notifications and existing widgets after upgrade. The embedded Apple Watch application still has
   the upstream three-score design (`NOOPWatch/`, `NOOPWatchComplications/`, `WatchSessionBridge.swift`)
   and is not yet adapted. Historical recovery fields remain in storage for compatibility; shared
   analytics are not deleted. This is not a claim that every legacy surface has been removed.
3. **Collect inputs before tuning:** use the read-only night tool, record firmware/source/window and
   explain gaps. `distinct_seconds` and five-minute occupancy are observations, never continuous wear.
   Nonpositive/NaN checks are structural, not an arbitrary physiological range filter.
4. **Refine effort evidence:** current sample-duration integration credits up to two minutes across a
   gap and repeats the final gap; the sparse eligibility gate tests a span, not continuous coverage.
   Duplicate/unsorted input and corrected historical caches need dedicated replay evidence. Do not
   call the daily result complete merely because it is numeric. See [the method](EFFORT_METHOD.md).
5. **Sleep windows before phases:** independently collect attempt-to-sleep, bed and wake information;
   preserve correction provenance. Evaluate naps/quiet wake/fragmentation before promoting staging.
6. **Imports:** test conflicts, device changes, duplicate exports, units, time zones/DST and correction
   lineage using private copies; existing general-purpose explorers still use the repository's
   imported-first resolution. They need a source-by-source comparison redesign beyond the new home.
7. **Precision:** execute the preregistered [validation protocol](SLEEP_EFFORT_VALIDATION.md).
   No tuning against WHOOP scores and no relaxation of input gates to fill the UI.

Build/run steps and the evidence ledger are in [SLEEP_EFFORT_TESTING.md](SLEEP_EFFORT_TESTING.md).
