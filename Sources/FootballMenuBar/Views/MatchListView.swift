import SwiftUI

/// The menu bar popover contents: matches grouped by league, with refresh and
/// quit controls, plus empty and error states.
struct MatchListView: View {
    @EnvironmentObject private var store: MatchStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 320)
    }

    // MARK: - Header

    /// Day label shown in the stepper, e.g. `Thu, Jul 2`.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return f
    }()

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                Task { await store.stepDay(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("Previous day")
            .disabled(store.isSteppingDate)

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text(Self.dayFormatter.string(from: store.selectedDate))
                    .font(.headline)
                todayControl
            }

            Spacer(minLength: 0)

            Button {
                Task { await store.stepDay(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .help("Next day")
            .disabled(store.isSteppingDate)

            if store.isRefreshing || store.isSteppingDate {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Shows "Today" when the selected day is today, otherwise a control to
    /// jump back to today.
    @ViewBuilder
    private var todayControl: some View {
        if store.isViewingToday {
            Text("Today")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Button("Today") { Task { await store.goToToday() } }
                .buttonStyle(.borderless)
                .font(.caption2)
                .disabled(store.isSteppingDate)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let groups = store.matchesByLeague
        if let error = store.errorMessage, store.matches.isEmpty {
            errorState(error)
        } else if groups.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups, id: \.league.id) { group in
                        leagueSection(group.league, matches: group.matches)
                    }
                }
                .padding(.vertical, 10)
            }
            // A vertical ScrollView has no intrinsic height; inside the
            // self-sizing MenuBarExtra window it would collapse to zero and the
            // list would look empty. Give it a concrete, content-aware height.
            .frame(height: scrollHeight(for: groups))
        }
    }

    /// Height for the scroll area sized to its content (rows + league
    /// headers), bounded so a busy matchday scrolls rather than growing the
    /// popover without limit.
    private func scrollHeight(for groups: [(league: League, matches: [Match])]) -> CGFloat {
        let rows = groups.reduce(0) { $0 + $1.matches.count }
        let headers = groups.count
        let estimate = CGFloat(rows) * 36 + CGFloat(headers) * 28 + 20
        return min(max(estimate, 80), 400)
    }

    private func leagueSection(_ league: League, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(league.displayName.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
            ForEach(matches) { match in
                MatchRow(match: match)
            }
        }
    }

    /// Short day label for the empty state, e.g. `Jul 2`.
    private static let emptyDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f
    }()

    private var emptyState: some View {
        VStack(spacing: 10) {
            stateMessage(
                icon: "calendar",
                title: "No matches on \(Self.emptyDayFormatter.string(from: store.selectedDate))",
                subtitle: store.isViewingToday
                    ? "Nothing live or scheduled in your leagues today."
                    : "Nothing scheduled in your leagues that day.")
            if !store.isViewingToday {
                Button("Back to today") { Task { await store.goToToday() } }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 8)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            stateMessage(icon: "wifi.exclamationmark", title: "Couldn't load scores", subtitle: message)
            Button("Retry") { Task { await store.refresh() } }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }

    private func stateMessage(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundStyle(.secondary)
            Text(title).font(.callout.weight(.medium))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            settingsControl

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// Opens the standard Settings window. This accessory (Dock-less) app has no
    /// app menu, so the AppKit `showSettingsWindow:` action sent through the
    /// responder chain finds no target and silently no-ops. `SettingsLink`
    /// (macOS 14+) opens and activates the Settings scene reliably; on the
    /// macOS 13 floor we fall back to the (best-effort) action send.
    @ViewBuilder
    private var settingsControl: some View {
        if #available(macOS 14, *) {
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Settings")
        } else {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Settings")
        }
    }
}

/// A single match row: a pin control, each team with its logo, the score on the
/// right, and a status badge.
private struct MatchRow: View {
    @EnvironmentObject private var store: MatchStore
    @EnvironmentObject private var settings: AppSettings
    let match: Match

    /// The team whose abbreviation is being edited, driving the entry alert.
    @State private var editingTeam: Team?
    @State private var draftAbbreviation = ""

    private var isPinned: Bool { store.pinnedMatchID == match.id }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            pinButton
            VStack(alignment: .leading, spacing: 2) {
                teamLine(match.home)
                teamLine(match.away)
            }
            .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if match.state == .upcoming {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    Text("\(match.score.home)").fontWeight(match.isLive ? .bold : .regular)
                    Text("\(match.score.away)").fontWeight(match.isLive ? .bold : .regular)
                }
            }
            .font(.subheadline.monospacedDigit())
            statusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .alert("Team abbreviation", isPresented: editingAlertBinding) {
            TextField("Abbreviation", text: $draftAbbreviation)
            Button("Save") {
                if let team = editingTeam { settings.setAbbreviation(draftAbbreviation, for: team) }
                editingTeam = nil
            }
            Button("Cancel", role: .cancel) { editingTeam = nil }
        } message: {
            if let team = editingTeam {
                Text("Shown for \(team.name) in the menu bar and where a logo isn't available. Leave blank to reset.")
            }
        }
    }

    /// Presents the entry alert while a team is being edited.
    private var editingAlertBinding: Binding<Bool> {
        Binding(get: { editingTeam != nil },
                set: { if !$0 { editingTeam = nil } })
    }

    private func teamLine(_ team: Team) -> some View {
        HStack(spacing: 6) {
            TeamLogoView(team: team)
            Text(team.name).lineLimit(1)
        }
        .contextMenu {
            Button("Set abbreviation…") {
                draftAbbreviation = settings.effectiveAbbreviation(for: team)
                editingTeam = team
            }
            if settings.hasOverride(for: team) {
                Button("Reset to default") { settings.clearAbbreviation(for: team) }
            }
        }
    }

    private var pinButton: some View {
        Button {
            store.togglePin(match)
        } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .foregroundStyle(isPinned ? Color.accentColor : .secondary)
                .imageScale(.small)
        }
        .buttonStyle(.borderless)
        .help(isPinned ? "Unpin from menu bar" : "Pin to menu bar")
    }

    private var statusBadge: some View {
        Text(match.statusDetail)
            .font(.caption2)
            .foregroundStyle(match.isLive ? .white : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(match.isLive ? Color.red : Color.clear, in: Capsule())
            .frame(minWidth: 44, alignment: .trailing)
    }
}
