# Sleep/effort batch: software validation record

This supersedes the initial testing ledger. No owner health recording was collected, uploaded or
evaluated. Implementation, compiled software, device operation and physiological accuracy are
separate states. The latter two remain unvalidated.

## Preserved history

Branch: `sleep-effort-reliability`, based on `design-personnalise` (`6ef61b3d`). No reset, main merge,
release, tag or health-data artifact publication is part of validation.

| Commit | Change |
|---|---|
| `fb1bf8b740172f14531f8eb135bcc736ea2f1476` | Swift/Kotlin effort input refusal, paired tests and method documentation. |
| `2e2af2669dc33fc93d3fdf92d862c2baa6a4f818` | Read-only night inventory, synthetic SQLite tests, validation protocol and Windows catalog-path normalization. |
| `b70419c260afa64c7f332dfd688c855db299f90a` | Personal iOS home, independent goals, fixed 0–21 presentation and initial recovery removal. |
| `15e01d6b8c4f5efd5b725a460a1a8e86b131d4de` | Legacy routes, Watch/widget compatibility, refusal categories, display precision and Windows diagnostic-test corrections. |
| `e6116cf3e221bd52d55a79a0727031b8bdc80647` | Transactional SQLite export and WAL/concurrency tests; further legacy gates; first SwiftUI compiler fixes; paired diagnostic-contract update; Linux Swift CI. |
| `b00e487bc6c0b96d7a5812ca024a4cefb779636e` | Remaining SwiftUI fix, pinned compiled Swift/Kotlin oracle, consistent narrative scale, neutral loading placeholders, corrupt-source test and focused manual validation scope. |
| `86cf1ce6751939a05c7e1ac71a20093a14beece8` | Optional Intel CI fallback and evidence/documentation updates only. Product/test trees are byte-identical to `b00e487b`. |

`personal_catalog_update.py` was a one-use, untracked catalog-editing helper in the parent workspace.
It was removed: `git ls-files '*catalog_update*'` is empty and
`Test-Path ..\personal_catalog_update.py` is false. It is not a durable tool or part of any commit.

## Six original Windows failures

Each full command is `python -X utf8 -m unittest -v <identifier>` from `Tools`, using the exact
identifier below. `<TEMP>` replaces private temporary paths. All six tests and the checker were
unchanged by the initial three commits.

| Identifier | Error and demonstrated cause | Impact and result |
|---|---|---|
| `tests.test_parity_ledger.ParityLedgerTests.test_base_semantic_state_survives_a_symlinked_temp_root` | `[WinError 1314]` at `link.symlink_to(real, target_is_directory=True)`, line 111. A separate minimal symlink probe outside the sandbox fails identically; `whoami /priv` lacks `SeCreateSymbolicLinkPrivilege`. | Fixture creation fails before `_base_semantic_state` runs. No scanner behavior can be inferred. Test unchanged, no skip/junction substitution; actual symlink test passed on Ubuntu in runs `43315249192` and `43320865681`. |
| `tests.test_parity_ledger.ParityLedgerTests.test_expand_twin_map_accepts_a_symlinked_root` | `[WinError 1314]` at `link.symlink_to(self.root, target_is_directory=True)`, line 142. Same independently reproduced token privilege refusal. | Fails before `expand_twin_map` executes. Test unchanged; actual symlink passed on Ubuntu in both runs above. Still not executable with this local Windows token. |
| `test_check_source_references.SourceReferenceTests.test_missing_symbol_reports_line_and_failure` | Exact diagnostic differs: expected `FAIL <TEMP>\docs\PROTOCOL.md:2 ... [missing] symbol not found`; actual uses `/`. The fixture interpolates `str(Path)`, while production `display_path` deliberately calls `as_posix()`. | Exit 1, symbol refusal and line 2 were correct. Expected path now uses `doc.as_posix()`; exact full message, line, exit code and failure count retained. Passes Windows/Ubuntu. |
| `test_check_source_references.SourceReferenceTests.test_missing_link_target_reports_file_failure` | Same exact-path assertion mismatch at `PROTOCOL.md:1`, with `file does not exist`. | Missing Markdown target correctly refused. Expected path normalized; exact refusal/status/count assertions retained. Passes both hosts. |
| `test_check_source_references.SourceReferenceTests.test_missing_backtick_target_reports_file_failure` | Same path mismatch for a backtick reference to a missing Python file. | File rejection itself correct. Expected path normalized, exact assertions retained. Passes both hosts. |
| `test_check_source_references.SourceReferenceTests.test_qualified_signature_extracts_final_symbol_and_matches_whole_words` | Same diagnostic-path mismatch for `[decode] symbol not found`. | Qualified extraction and whole-word refusal of `decode` when only `decodeAll` exists were correct. Both remain asserted, along with exact failure/status/count. Passes both hosts. |

A seventh test pins `PureWindowsPath("Z:/synthetic/docs/PROTOCOL.md")` to POSIX output. Production
diagnostics were not changed to satisfy the tests.

Repeated Windows runs: **202 Tools/tests cases: 200 passed, two symlink errors**; **154 core Tools
cases passed**; **234 linux-capture cases, one existing skip**; final **17 night inventory cases
passed** separately. Translation/doc-comment gates and `git diff --check` passed; no allowance was
increased. All fixture data is synthetic, including any physiological-looking test stdout.

## Workflows and exact source

Earlier green runs do not validate later edits. These validation workflows contain no release or
artifact-upload step. App build dispatch uses `inputs.pr=""`, building the branch as-is.
Do not use `fork-testing-build.yml`, which creates a prerelease.

| Source | Workflow | Actual result |
|---|---|---|
| `15e01d6b` | [App 43315238414](https://github.com/ibradamm/noop/actions/runs/43315238414) | Both builds failed at `OnboardingWizard.swift:296`: modifier after conditional view. Tests did not execute. Conditional views now wrapped in `Group`. |
| `15e01d6b` | [Android 43315245557](https://github.com/ibradamm/noop/actions/runs/43315245557) | APK built; 6,757 tests, one failed, six skipped. Funnel test expected one line after the new refusal line was added. Swift/Kotlin now assert both ordered lines plus the original funnel and nil score. |
| `15e01d6b` | [Python 43315249192](https://github.com/ibradamm/noop/actions/runs/43315249192) | Passed: capture 234 (one skip), governance 50, R-R contracts two, night inventory 17, actual symlinks two, core 154. |
| `15e01d6b` | [Swift 43315241760](https://github.com/ibradamm/noop/actions/runs/43315241760) | Cancelled after inspecting unstarted queued jobs; replaced by corrected source. No green claim. |
| `e6116cf3` | [App 43320834988](https://github.com/ibradamm/noop/actions/runs/43320834988) | macOS failed at `InsightsHubView.swift:78`: same conditional-view modifier pattern. Corrected; this run does not prove successful app compilation. |
| `e6116cf3` | [Swift 43320844420](https://github.com/ibradamm/noop/actions/runs/43320844420) | Linux passed: Swift 6.4.2 x86_64; protocol 857 (one skip), storage 634, analytics 2,157, zero failures. Mac package legs queued when inspected. |
| `e6116cf3` | [Python 43320865681](https://github.com/ibradamm/noop/actions/runs/43320865681) | Passed, including both unchanged real-symlink regressions. |
| `e6116cf3` | [Android 43320852570](https://github.com/ibradamm/noop/actions/runs/43320852570) | Passed; final head must also include the pinned compiled oracle. |
| `b00e487b` | [App 43323122998](https://github.com/ibradamm/noop/actions/runs/43323122998) | Workflow failed due to unacquired Mac runner. iOS Simulator leg passed, both architectures, including Watch/complications and new SQLite helper. Mac build/tests did not run. |
| `b00e487b` | [Swift 43323127415](https://github.com/ibradamm/noop/actions/runs/43323127415) | Workflow failed due to four unacquired Mac runners. Linux passed: protocol 857 (one skip), storage 634, analytics 2,157, zero failures; pinned oracle passed. Unrelated tools outside focused scope. |
| `b00e487b` | [Android 43323131163](https://github.com/ibradamm/noop/actions/runs/43323131163) | Debug APK and full fresh unit suite passed. Targeted oracle passed and printed exactly the four Swift expected lines. |
| `b00e487b` | [Python 43323134463](https://github.com/ibradamm/noop/actions/runs/43323134463) | Passed: 234 capture (one skip), 50 governance, two R-R contracts, 17 night inventory, two real symlinks, 154 core tests. |
| `86cf1ce6` | [App 43326184344](https://github.com/ibradamm/noop/actions/runs/43326184344) | Both app builds passed. Mac tests compiled but host aborted before the first test: `MTLLoader` asserted `Target device architecture is nil`, then SIGABRT. No executed app-test success claimed. |
| `86cf1ce6` | [Swift 43326187421](https://github.com/ibradamm/noop/actions/runs/43326187421) | Passed: Mac protocol 857 (one skip), storage 645, analytics 2,157, design 137. Linux protocol/store/analytics passed again (857/634/2,157). Compiled oracle agreed on both hosts. |
| `86cf1ce6` | [Python 43326191400](https://github.com/ibradamm/noop/actions/runs/43326191400) | Passed all six steps, including both real symlinks. |

The remaining app-test result is pending in this draft. UI/numerical changes were frozen at
`b00e487b`; the SQLite progress timeout and hosted-test launch received a subsequent targeted fix.
Subsequent documentation/runner-selection changes do not change product source or assertions.
Manual Swift
`validation_scope=effort` runs the four relevant packages (protocol, storage, analytics, presentation)
on macOS plus the Linux leg. Normal/full runs retain all packages/tools; no assertions or failure
gates are relaxed.

All four cancelled Mac package jobs (`131548674433`, `131548674745`, `131548674824`, `131548674866`)
and the cancelled Mac app job (`131548860395`) have empty runner
names and failure annotations: “The job was not acquired by Runner of type hosted even after
multiple attempts”, plus notices about macOS arm64 capacity constraints. This is direct hosting
evidence, not an attribution inferred from a failed test. An optional `macos_runner=macos-15-intel`
fallback is provided using an [official hosted-runner label](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
Defaults remain unchanged. The app still builds both x86_64/arm64; hosted tests execute on the
chosen host architecture. Cancelled/unstarted tests remain unvalidated until their replacement runs.

`git diff --exit-code b00e487b 86cf1ce6 -- Packages Strand StrandTests StrandiOS StrandiOSShared
StrandiOSWidgets NOOPWatch NOOPWatchComplications android Tools project.yml` returned 0. Therefore
the Android result on `b00e487b` is tied to identical Android source/tests and cross-language fixtures;
it is not being used to validate the modified Apple runner selection. That selection is executed by
the `86cf1ce6` workflows themselves.

Existing conditional skips were inspected: protocol `testFullCorpusDecodesWithPublishedInvariants`
requires the private `WHOOP_R20_CORPUS`; Python `test_integration_real_db_if_present` requires a real
capture DB. Neither was supplied or published. These are not newly disabled assertions, and no real
corpus/integration success is claimed. The two new presentation test functions both executed and
passed inside StrandDesign's 137-test suite.

The Intel app-test failure is a separate observed cause from the earlier queue failures. The
universal build succeeded and `SQLiteBackupSnapshotTests`/`PersonalSnapshotCompatibilityTests`
compiled in StrandTests, then the host launched the full product UI/live services and aborted in
Metal before XCTest execution. The DEBUG-only `NOOP_UNIT_TEST_HOST=1` scheme environment now selects
empty root/menu content for hosted logic tests. All real UI still compiles in the normal build;
all test assertions remain enabled. This harness does not establish GPU rendering or device UI
behavior. The replacement run must prove that the tests actually start and finish.

## SQLite export

The checkpoint/copy race was reproduced with a synthetic WAL DB: checkpoint after row 1, commit row
2; live count 2, immutable main-file count 1, and main-file `quick_check` still `ok`. Integrity alone
cannot establish inclusion of committed WAL pages.

[The SQLite snapshot helper](../Strand/Data/SQLiteBackupSnapshot.swift) opens the source read-only,
holds one read transaction across online-backup steps, includes committed WAL pages visible when
that snapshot starts, then finalizes a standalone destination in DELETE journal mode. Later commits
continue outside the fixed snapshot. Busy/locked/incomplete/error results refuse export. Existing
destinations are preserved; failed staging is removed; source records are unchanged.
The five-second deadline bounds continuous busy/locked retries, not the total duration of a large
copy that is making progress.

[The production export path](../Strand/Data/DataBackup.swift) checks the isolated snapshot before archiving,
retains existing post-write/restore checks and cleans its private staging directory. Historical rows,
schema, settings whitelist and ZIP entry `noop-backup.sqlite` are unchanged. Android's checkpoint/copy
implementation is not changed by this Apple I/O correction and has not gained this concurrency
guarantee. Archive decoding remains cross-platform compatible.

[The snapshot tests](../StrandTests/SQLiteBackupSnapshotTests.swift) assert:

- Nonempty committed WAL inclusion and stability after later source writes.
- The production ZIP path includes a post-checkpoint commit; extracted DB contains both rows.
- A 64 MiB multi-step copy overlaps another connection's commits, proven by monotonic commit times.
  Forty transactions update a two-row invariant together, with passive checkpoints. Snapshot revisions
  must match, all 512 padding rows remain, source reaches revision 40, integrity passes, and no
  destination WAL is required.
- Missing/corrupt source refusal, preserved source, no partial destination, existing-file preservation.
- An exclusively locked source returns a busy/locked error and leaves no partial destination;
  releasing the lock reveals the original committed row unchanged. Existing-destination refusal also
  pins its specific Cocoa error, so a missing-source error cannot make that test pass by accident.

Membership: `project.yml` recursively includes `Strand` in both Strand and NOOPiOS, without excluding
the helper. Recursive `StrandTests` includes the tests; the Strand scheme runs that bundle. Compiler
and test logs must confirm this inspected configuration. Generated Xcode projects are not edited.
iOS builds include embedded Watch/widgets; they do not execute iOS UI tests.

SQLite consistency does not imply an atomic transaction across SQLite and UserDefaults. Settings
JSON is captured separately; keep calculation settings stable during pilot export and record them.

## Input refusal and display audit

| Case | Behavior |
|---|---|
| Invalid configuration | Nonfinite HRmax/RHR/denominator, RHR ≤ 0, HRmax ≤ RHR, denominator ≤ 1: unavailable, `invalid_configuration`. Valid reserve/log map does not exist. |
| Rejected sample | Nonpositive BPM still in scorer input: whole window unavailable, `rejected_hr_samples count=N`. Silently dropping it joins neighbors and credits an unsupported interval. An exclusion mask would require a separate algorithm change. Raw history retained; no invented upper BPM threshold. |
| Insufficient evidence | Existing minimum count/span gate fails: unavailable, `insufficient_coverage`, then existing funnel. 600 samples, or 20 spanning 600 seconds, does not establish continuous wear. |
| Observed calm input | Valid zero stays zero, distinct from nil/null. |

Compiled oracle: 600 synthetic 160 BPM samples at 1 Hz, HRmax 190, default RHR 60. Stored values:
Edwards male/female `38.66`; Banister male `35.30`, female `36.19`. Exact stdout copied from Swift
Linux job `131540778101` into both tests, with invalid/refusal cases asserted separately.

| Surface | Personal iOS policy |
|---|---|
| Home/goals | Exact active computed namespace, separate commercial comparison. User goal 0–21, initially unset, independent of recovery. |
| Calculation/history | Independent existing TRIMP/log map; daily window independently scored, no session-score summation. Stored/backup axis 0–100. |
| Details/charts/text | Fixed iOS scale resolver; values/deltas/axis labels/current narrative factor use 0–21. Missing live effort is a dash. |
| Widgets | Shared formatter, precise optional stored effort; old integer/0–100 fields retained. Stale/unmarked score cache withheld pending republication. No recovery; no measurements in loading placeholder. |
| Watch | Sleep/effort only, effort gauge/text 0–21. Installed kind retained. No automatic Debug demo seeding; gallery preview never enters runtime timeline. |
| Shared payloads | Additive optional `personalPolicyVersion` and widget `effortStored`; old recovery/0–100 payloads still decode. Compatibility tests cover precision and change detection. |
| Legacy/advice | Stale Coach/Journal/Intelligence/Insights links blocked. Old AskCoach intent inactive. iOS runtime gates stop Coach briefs, recovery-gated live coaching and recovery-based target notifications. Setup removes old delivered/pending recovery notifications. |
| Help/settings/debug | Recovery cards/calibration/alternative HRV-readiness hidden; onboarding/help updated; obsolete Debug routes use personal home. Unrelated sleep/activity/strength functions retained. |

This is source inspection and specific automated evidence, not an installed-device traversal or
WatchConnectivity/notification test. General history explorers keep upstream source resolution;
their imported history is not certified as the personal home's independent estimate. No recovery
history is deleted.

## Prepared first-night protocol — conditional on software success

First pass final builds/tests, then install that exact source. A simulator build does not install
itself on an iPhone.

1. Update without uninstalling/clearing data. Check Home/Health/More, source labels, missing dashes,
   goals, old links/widgets/notifications. If used, update the Watch and an already-installed face.
2. Record commit/build, WHOOP 5 firmware, active device, wear site, timezone and profile assumptions
   locally. Complete history sync; note gaps. Test a strap alarm separately with a dependable backup
   alarm: operation on this owner's hardware is unverified.
3. Privately copy [the empty diary](validation/session-log-template.csv). Record bed, attempt to
   sleep, known wake and out-of-bed separately with UTC offsets. Unknown stays empty. No latency
   inferred from first detected sleep.
4. Export NOOP backup in Settings to local iPhone Files, then transfer a private copy by USB. Keep
   health files outside the repo and OneDrive workspace, e.g. under `%LOCALAPPDATA%`. Preserve the
   original `.noopbak` and SHA-256. Keep calculation preferences unchanged during export.
5. Extract `noop-backup.sqlite` from a private ZIP copy, never copy the live main DB. Run inventory
   using the exact device identifier and actual half-open night interval; these are placeholders:

   ```powershell
   python -X utf8 Tools/night_signal_audit.py --db "<PRIVATE>\noop-backup.sqlite" --device "<EXACT_ID>" --start "2026-11-12T23:00:00+01:00" --end "2026-11-13T08:00:00+01:00"
   ```

6. Inspect counts, gaps, device separation and refusals locally. Keep DB, diary, screenshots and full
   reports private; publish no health recordings/artifacts. Fix collection/export issues before tuning.

One night is a collection/export rehearsal and subjective annotation comparison, not validation of
stages, stress, effort, HR, calorie or VO₂ precision. Independent reference studies remain in
[the validation protocol](SLEEP_EFFORT_VALIDATION.md).
