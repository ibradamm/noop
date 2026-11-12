# Build, collect and verify the personal iOS edition

**Current follow-up:** [batch validation record](SLEEP_EFFORT_BATCH_VALIDATION.md). The ledger below
records the initial attempt. Native/Watch statements there are historical; the follow-up tracks
exact tested commits and the remaining gates.

Start with [the feature audit](SLEEP_EFFORT_AUDIT.md). This branch is an initial implementation
batch, not a ready-to-install validated release. No Apple password is needed for these checks.

## Windows: checks available now

Open PowerShell in the **repository** folder (the `noop` child folder, not its parent):

```powershell
git branch --show-current
git status --short
python -X utf8 -m unittest discover -s Tools/tests -p test_night_signal_audit.py -v
python -X utf8 Tools/doc_comment_lint.py
python -X utf8 Tools/i18n_audit.py --ci design-personnalise
git diff --check
```

`-X utf8` avoids Windows console encoding failures on translated text. The audit tests create
temporary synthetic databases; they never read the owner's health records. CI now explicitly runs
`tests.test_night_signal_audit` in `.github/workflows/tools-python.yml` so these tests are not
silently omitted by the separate core-test discovery.

## Native tests and compilation still required

On a macOS machine/runner with the Xcode SDK required by `project.yml` and `app-build.yml`:

```sh
swift test --package-path Packages/WhoopProtocol
swift test --package-path Packages/WhoopStore
swift test --package-path Packages/StrandAnalytics
xcodegen generate
xcodebuild -project Strand.xcodeproj -scheme NOOPiOS \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Strand.xcodeproj -scheme Strand \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

`StrainInputValidityTests.swift` covers both recipes, nonfinite parameters, invalid denominators,
nonpositive HR, a genuine zero, missing data and the refusal diagnostic. The corresponding Kotlin
cases are in `StrainInputValidityTest.kt`. They are written, **not executed here**. After installing
JDK 17 and the repository-required Android SDK, the targeted Windows command is:

```powershell
.\android\gradlew.bat -p android testFullDebugUnitTest --tests com.noop.analytics.StrainInputValidityTest --no-build-cache --rerun-tasks
```

Run the broader native suite and app compilation before merging. A compiled Swift-versus-Kotlin
oracle must still confirm the valid/invalid corpus: no byte-parity execution is claimed from reading
the two files. The existing GitHub **App build (macOS + iOS)** workflow has a manual dispatch, builds
both app schemes and runs macOS app tests. It needs the changes present on a remote branch; local
uncommitted edits cannot be checked by that runner. No remote build or release was started in this
session. The old iMac is not assumed capable of the required SDK. Signing and sideloading steps
remain in [IOS.md](IOS.md); the build commands above require no signing credential.

## First iPhone/WHOOP 5 trial

1. Build/install only after the native build gate succeeds. Keep the old installation/data backed up
   using the existing consistent export path; do not uninstall to update.
2. Verify Accueil / Santé / Plus; open sleep, workouts, strength logs, sources, alarms and history.
   Check small screens, larger text and returning to a tab root. Home sleep/effort stay `—` when
   unavailable. User goals start unset. The sleep-circle fill only reflects a chosen duration goal.
3. Traverse previously enabled settings, delivered notifications, old quick actions, help, imported
   data and widgets after upgrade. Confirm that recovery/readiness and Coach do not reappear. The
   Apple Watch companion is still an explicit remaining migration item, not a completed feature.
4. Confirm live HR, successful history sync, selected physical device and firmware. Note dropouts;
   connected/live HR does not prove complete overnight history. No new configuration writes are
   required by the inventory tool.
5. Record an actual night's bed/attempt/wake/rise information using the private copy of the
   [session template](validation/session-log-template.csv). Unknown times remain empty. Repeat for
   naps and fragmented nights before treating the detector as reliable.
6. Export a **consistent SQLite snapshot** using the existing backup/export tooling. Preserve the
   original. A `.noopbak` is a ZIP container, not a SQLite file; extract a private copy locally if
   necessary. Do not copy a live SQLite main file while writes remain in its WAL. If export consistency
   cannot be established, stop rather than treating omitted rows as unavailable sensor data.
7. Use the exact exported `deviceId` (not a guessed alias), and actual timestamps with UTC offsets:

```powershell
python -X utf8 Tools/night_signal_audit.py --db "C:\Private\night.sqlite" --device "EXACT_DEVICE_ID" --start "2026-11-11T23:00:00+01:00" --end "2026-11-12T08:00:00+01:00"
```

The example times and identifier are placeholders. The window is half-open `[start,end)` and at
most 48 elapsed hours. Offsets are mandatory, including across DST/travel; fractional bounds are
refused rather than rounded. The script opens the snapshot read-only/immutable and refuses a
nonempty WAL/journal sidecar. A detached, incomplete main-file copy cannot be detected reliably:
the consistent export is still required.

The output contains counts, relative timestamp coverage and structural warnings, not raw HR/RR,
device identifiers, absolute timestamps or scores. Malformed channel payloads are redacted. Review
the report before sharing; even aggregate sleep metadata can be personal. Keep databases, diaries,
raw captures and full reports outside this repository and public artifacts.

One populated five-minute bin can contain one sample. Several RR intervals in one second may be
different beats. “Recognized transport” does not mean eligible HRV. “Structurally usable” does not
mean physiologically accurate. Sparse input must not be repaired by filling zeros or relaxing gates.

Test an alarm separately with a dependable backup alarm. Record the actual vibration, cancellation,
weekday and clock/DST behavior. A successful write/readback is not proof that it woke the wearer.

## Evidence ledger — 2026-11-12

| Check | Actual result | What it establishes |
|---|---|---|
| Night inventory tests | **17 passed**, synthetic temporary SQLite fixtures | Read-only behavior, missing/corrupt inputs, device/window separation, duplicate/conflicting HR seconds, RR provenance/quarantine, old schemas, explicit offsets/DST, no raw-data output, WAL refusal. Not physiological precision. |
| Broader `Tools/tests` discovery | 201 executed: **199 passed, 2 errors** | The two existing symlink tests in `test_parity_ledger.py` fail with Windows privilege error 1314. No gate was weakened. This run collected the audit's earlier 16-case version; its final 17-case suite was run separately. |
| Core Tools Python suites | 153 executed: **149 passed, 4 failed** | Expectations interpolate Windows backslashes, while production diagnostics intentionally use POSIX separators. The follow-up fixes expected paths while retaining exact assertions. |
| Declaration parity refresh | **Passed**, 288 known findings, no derived-file diff | Existing declaration governance accepts the source inventory. It is not numerical Swift/Kotlin execution evidence. |
| Detached doc-comment lint | **Passed** | No new detached comments; upstream baseline remains. |
| Translation gate vs `design-personnalise` | **Passed** after fixing Windows catalog path normalization; no allowances increased | Added personal UI text has translations across shipped locales, including French. Native layout/native-speaker review is still pending. |
| Targeted translation-tool tests | **83 passed** | Existing audit scanner regression cases after the Windows path fix. |
| Targeted home/localization contracts | **29 passed** | Existing source/localization contracts; not SwiftUI compilation or a device test. |
| Documentation source references | **21 checked, 0 failures** | Referenced source files in the new audit/method/protocol/testing documents exist. |
| `git diff --check` | **Passed** | No whitespace errors. |
| Swift analytics tests | **Could not start**: Swift not installed | No Swift runtime or compiled numerical-parity result. |
| Android targeted test | **Could not start**: no Java/JAVA_HOME | No Kotlin/Gradle compilation result. |
| Apple app builds | **Not run**: Windows, no Xcode/macOS runner used | No iOS/macOS compilation claim. |
| WHOOP 5 / iPhone operation | **Not run** | No hardware evidence from this owner. |
| Independent precision evaluation | **Not run; no real data supplied** | No validated sleep stage, stress, effort, HR, calorie or VO₂ accuracy claim. |

## Boundaries of this batch

The new home and score widgets use exact active computed sources. The live-HR banner currently
omits effort because its legacy synchronous row cannot establish the score's provenance. It still
shows real live HR/link state; no commercial score is relabelled as NOOP there. Widgets now detect
the logical-day boundary as well as the calendar-day boundary before reusing score fields.

General-purpose detail screens still use existing source-resolution policies; import conflicts,
the full legacy navigation/help/share audit and the embedded Watch migration remain in the
prioritized audit. Existing historical rows are retained. Changes here are source edits; an app
upgrade and real-device traversal are required to establish what the wearer actually sees.
