#if os(iOS)
import SwiftUI
import StrandDesign

/// Personal iOS dashboard. Local estimates and imported scores are read separately.
/// Legacy recovery/readiness screens are never used as the home fallback.
struct SleepEffortHomeView: View {
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var router: NavRouter
    @State private var dayOffset = 0
    @State private var values: [String: Double] = [:]
    @State private var previous: [String: Double] = [:]
    @State private var importedEffort: Double?
    @State private var loadedDay: String?
    @State private var loadedDevice: String?
    @AppStorage("personal.sleepGoalMinutes") private var sleepGoalMinutes = 0
    @AppStorage("personal.effortGoal21") private var effortGoal21 = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { clock in
            let date = Calendar.current.date(byAdding: .day, value: dayOffset,
                                             to: Repository.logicalDay(clock.date)) ?? clock.date
            let day = Repository.localDayKey(date)
            ScreenScaffold(title: "Home", subtitle: "\(day)",
                           onRefresh: { await repo.refresh() }) {
                HStack {
                    Button { dayOffset -= 1 } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous day")
                    Spacer()
                    Button("Today") { dayOffset = 0 }
                    Spacer()
                    Button { dayOffset += 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(dayOffset >= 0)
                        .accessibilityLabel("Next day")
                }
                .font(StrandFont.headline)
                .tint(StrandPalette.effortColor)

                NoopCard {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: NoopMetrics.space6) { pillars(day: day) }
                        VStack(spacing: NoopMetrics.space6) { pillars(day: day) }
                    }
                }
                Text("NOOP estimates · active device · accuracy has not been validated on this strap.")
                    .font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)

                NoopCard {
                    VStack(alignment: .leading, spacing: NoopMetrics.cardInnerSpacing) {
                        Text("Compared with the previous day").font(StrandFont.headline)
                        comparison("Sleep", key: "sleep_total_min", day: day, duration: true)
                        comparison("Effort", key: "strain", day: day, duration: false)
                        if loadedDay == day, loadedDevice == repo.deviceId, let importedEffort {
                            Text("Imported WHOOP: \(UnitFormatter.effortDisplay(importedEffort, scale: .whoop)) / 21")
                                .font(StrandFont.body)
                            Text("Commercial comparison kept separate from the NOOP calculation.")
                                .font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
                        }
                    }
                }
                NoopCard {
                    VStack(alignment: .leading, spacing: NoopMetrics.cardInnerSpacing) {
                        Text("Your chosen goals").font(StrandFont.headline)
                        Stepper(value: $sleepGoalMinutes, in: 0...960, step: 30) {
                            if sleepGoalMinutes > 0 { Text("Sleep goal: \(duration(Double(sleepGoalMinutes)))") }
                            else { Text("Sleep goal: none") }
                        }
                        Stepper(value: $effortGoal21, in: 0...21) {
                            if effortGoal21 > 0 { Text("Effort goal: \(effortGoal21) / 21") }
                            else { Text("Effort goal: none") }
                        }
                        Text("These choices are neither a physiological need nor a recommendation.")
                            .font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
                    }
                }
                NoopCard {
                    VStack(alignment: .leading, spacing: NoopMetrics.cardInnerSpacing) {
                        NavigationLink(value: TabRoute.sleep) { Label("Nights and naps", systemImage: "moon.stars") }
                        NavigationLink(value: TabRoute.workouts) { Label("Activities and heart-rate curves", systemImage: "figure.run") }
                        NavigationLink(value: TabRoute.liftLog) { Label("Strength training", systemImage: "dumbbell") }
                        NavigationLink(value: TabRoute.metricExplorer) { Label("Steps, calories, VO₂ max and history", systemImage: "chart.xyaxis.line") }
                        Button { router.openDevices() } label: { Label("Strap and sync", systemImage: "antenna.radiowaves.left.and.right") }
                    }
                    .font(StrandFont.headline)
                }
                Text("Missing values stay unavailable. Samples do not establish continuous coverage. Sleep stages and nocturnal stress remain experimental.")
                    .font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
            }
            .task(id: "\(day)|\(repo.refreshSeq)|\(repo.deviceId)") { await load(day: day, date: date) }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private func pillars(day: String) -> some View {
        let current = loadedDay == day && loadedDevice == repo.deviceId
        let sleep = current ? values["sleep_total_min"] : nil
        let effort = current ? values["strain"].map { UnitFormatter.effortValue($0, scale: .whoop) } : nil
        pillar("Sleep", value: sleep.map(duration),
               fraction: sleepGoalMinutes > 0 ? sleep.map { $0 / Double(sleepGoalMinutes) } : nil,
               unit: "hours : minutes · estimated", tint: StrandPalette.restColor)
        pillar("Effort", value: effort.map { String(format: "%.1f", $0) },
               fraction: effort.map { $0 / 21 }, unit: "/ 21 · NOOP estimate", tint: StrandPalette.effortColor)
    }

    private func pillar(_ title: LocalizedStringKey, value: String?, fraction: Double?, unit: LocalizedStringKey, tint: Color) -> some View {
        VStack(spacing: NoopMetrics.space2) {
            ZStack {
                Circle().stroke(StrandPalette.textTertiary.opacity(0.2), lineWidth: NoopMetrics.space2)
                if let fraction {
                    Circle().trim(from: 0, to: min(max(fraction, 0), 1))
                        .stroke(tint, style: StrokeStyle(lineWidth: NoopMetrics.space2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(value ?? "—").font(StrandFont.title1).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(StrandPalette.textPrimary)
            }
            .frame(width: NoopMetrics.controlHeight * 2.5, height: NoopMetrics.controlHeight * 2.5)
            Text(title).font(StrandFont.headline)
            Text(value == nil ? "Unavailable" : unit).font(StrandFont.caption)
                .foregroundStyle(StrandPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func duration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        return "\(total / 60) : \(String(format: "%02d", total % 60))"
    }

    private func comparison(_ title: LocalizedStringKey, key: String, day: String, duration isDuration: Bool) -> some View {
        let ready = loadedDay == day && loadedDevice == repo.deviceId
        let current = ready ? values[key] : nil
        let prior = ready ? previous[key] : nil
        let text: String
        if let current, let prior {
            if isDuration {
                text = "\(duration(current)) / \(duration(prior))"
            } else {
                text = String(localized: "\(UnitFormatter.effortDisplay(current, scale: .whoop)) / \(UnitFormatter.effortDisplay(prior, scale: .whoop)) of 21")
            }
        } else {
            text = String(localized: "Comparison unavailable")
        }
        return HStack { Text(title); Spacer(); Text(text).bold().monospacedDigit() }
            .font(StrandFont.body)
    }

    @MainActor private func load(day: String, date: Date) async {
        // Exact computed namespace: the resolver's imported-first precedence must not
        // silently turn WHOOP's score into an independent NOOP estimate.
        let source = repo.deviceId + "-noop"
        let priorDate = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let priorDay = Repository.localDayKey(priorDate)
        var next: [String: Double] = [:]
        var before: [String: Double] = [:]
        for key in ["sleep_total_min", "strain"] {
            let result = await repo.resolvedSeries(key: key, source: source, from: priorDay, to: day)
            for point in result.points where point.value.isFinite && point.value >= 0 && point.value < Double(Int.max) {
                // Values outside the stored Effort domain are refused, never clipped into a score.
                if key == "strain" && point.value > 100 { continue }
                if point.day == day { next[key] = point.value }
                if point.day == priorDay { before[key] = point.value }
            }
        }
        let imported = await repo.resolvedSeries(key: "strain", source: Repository.whoopSource, from: day, to: day)
        let commercial = imported.points.first {
            $0.day == day && !$0.source.hasSuffix("-noop") && $0.value.isFinite && (0...100).contains($0.value)
        }?.value
        guard !Task.isCancelled, source == repo.deviceId + "-noop" else { return }
        values = next
        previous = before
        importedEffort = commercial
        loadedDay = day
        loadedDevice = repo.deviceId
    }
}
#endif
