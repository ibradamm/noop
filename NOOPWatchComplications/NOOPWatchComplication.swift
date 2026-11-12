import WidgetKit
import SwiftUI
import StrandDesign

// MARK: - NOOP watch-face complication
//
// The headline feature of M3: Charge (recovery) on the wrist. The iPhone is the brain
// (M1 computes Charge / Effort / Rest with confidence + provenance); this complication ONLY
// displays the latest `WatchScoreSnapshot` the phone pushed into the shared app group. It never
// recomputes a score.
//
// The honesty rule carries through from M1: a CALIBRATING score has a nil number plus its
// Calibrating flag set, and we render a dash with a subtle "cal" marker, never a fabricated
// number. When there is no snapshot at all we show a NEUTRAL placeholder (a dash + the NOOP
// glyph), not a zero, so an empty face never reads as "your Charge is 0".
//
// Families: accessoryCircular (ring + number), accessoryCorner, accessoryInline (text), and
// accessoryRectangular (a compact card with all three scores).

// MARK: - Snapshot access
//
// We read the app group directly here rather than depending on a loader symbol from the bridge
// lane, so this extension only needs the shared `WatchScoreSnapshot` type from StrandDesign. The
// suite + key match the cross-lane contract: the phone-side bridge writes the latest snapshot under
// `latestWatchSnapshot` to whatever app group `WatchScoreSnapshot.appGroupId` resolves to (the
// extension's own AppGroupIdentifier Info.plist key, injected from $(APP_GROUP_ID)/$(BUNDLE_ID_PREFIX)
// in project.yml, falling back to the canonical upstream group), and the watch app + this
// complication read the same value.

enum WatchSnapshotAccess {
    /// `Bundle.main` is process-global, so this is exactly the lookup `WatchScoreSnapshot.appGroupId`
    /// itself performs — deferring to it directly keeps the resolution in ONE place so the writer and
    /// every reader can never desync on it.
    static let suiteName: String = WatchScoreSnapshot.appGroupId

    static let storageKey = WatchScoreSnapshot.storageKey

    /// The last snapshot the phone pushed, or nil if nothing has synced yet.
    static func load() -> WatchScoreSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: storageKey),
              let snap = try? JSONDecoder().decode(WatchScoreSnapshot.self, from: data),
              snap.personalPolicyVersion == PersonalScoreDisplay.policyVersion else { return nil }
        return snap
    }
}

// MARK: - Timeline

/// One timeline entry, backed by the latest snapshot (or nil when nothing has synced).
struct ChargeEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchScoreSnapshot?
}

struct ChargeProvider: TimelineProvider {
    /// A friendly stand-in for the gallery / first paint. Shows a real-looking Charge so the
    /// complication previews well, but it is never persisted and the live view falls back to the
    /// neutral placeholder when there is genuinely no snapshot.
    func placeholder(in context: Context) -> ChargeEntry {
        ChargeEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargeEntry) -> Void) {
        // In the gallery (isPreview) show the friendly preview; on a real face show what synced.
        let snap = context.isPreview ? WatchScoreSnapshot.preview : WatchSnapshotAccess.load()
        completion(ChargeEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargeEntry>) -> Void) {
        let snap = WatchSnapshotAccess.load()
        // The phone forces a reload (WidgetCenter.reloadAllTimelines) whenever it pushes a fresh
        // snapshot, so this periodic refresh is just a backstop. Roughly every 30 minutes keeps the
        // "as of …" age honest without burning the watch's complication budget.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [ChargeEntry(date: Date(), snapshot: snap)], policy: .after(next)))
    }
}

// MARK: - Preview snapshot

private extension WatchScoreSnapshot {
    /// A representative snapshot for the widget gallery: a primed Charge, a mid Effort, a calibrating
    /// Rest (so the gallery also shows the cal marker), a live HR and a short sleep line.
    static var preview: WatchScoreSnapshot {
        WatchScoreSnapshot(
            charge: nil, chargeCalibrating: false,
            effort: 41, effortCalibrating: false,
            rest: nil, restCalibrating: true,
            hr: 58,
            sleepSummary: "7h 12m",
            asOf: Date(), personalPolicyVersion: PersonalScoreDisplay.policyVersion
        )
    }
}

// MARK: - Personal sleep / effort display
// Keep the installed widget kind and Codable payload compatible. Legacy recovery
// fields are decoded but never rendered, including old cached payloads.
struct NOOPChargeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ChargeEntry

    private var trusted: WatchScoreSnapshot? {
        guard let snap = entry.snapshot,
              snap.personalPolicyVersion == PersonalScoreDisplay.policyVersion,
              !snap.isStale(now: entry.date) else { return nil }
        return snap
    }
    private var effort: Double? {
        guard trusted?.effortCalibrating == false else { return nil }
        return PersonalScoreDisplay.effortValue(stored: trusted?.effort)
    }
    private var effortText: String {
        guard trusted?.effortCalibrating == false else { return "–" }
        return PersonalScoreDisplay.effortText(stored: trusted?.effort) ?? "–"
    }
    private var sleepText: String {
        guard let snap = trusted, !snap.restCalibrating, let rest = snap.rest,
              rest.isFinite, (0...100).contains(rest) else { return "–" }
        return String(format: "%.0f%%", rest)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Effort") + Text(verbatim: " " + effortText + " / 21")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("NOOP").font(StrandFont.caption)
                HStack {
                    cell("Effort", text: effortText + " / 21", tint: StrandPalette.effortColor)
                    cell("Sleep", text: sleepText, tint: StrandPalette.restColor)
                }
                if let snap = entry.snapshot {
                    Text(snap.freshnessText(now: entry.date)).font(StrandFont.footnote)
                }
            }
            .accessibilityElement(children: .combine)
        default:
            Gauge(value: effort ?? 0, in: 0...21) {
                Text("Effort")
            } currentValueLabel: {
                Text(effortText)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(effort == nil ? StrandPalette.textTertiary : StrandPalette.effortColor)
        }
    }

    private func cell(_ label: LocalizedStringKey, text: String, tint: Color) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(StrandFont.caption)
            Text(text).font(StrandFont.headline).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NOOPChargeComplication: Widget {
    // Keep the kind so existing installed faces update in place.
    let kind = "NOOPChargeComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargeProvider()) { entry in
            NOOPChargeView(entry: entry)
                .containerBackground(StrandPalette.surfaceBase, for: .widget)
        }
        .configurationDisplayName("NOOP")
        .description("Sleep and Effort")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}
