import SwiftUI

/// The menu bar popover contents: matches grouped by Competition, with refresh and
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
        // Pinned so the spinner/refresh swap and the "Today" text/button swap
        // can't change the header's height (see `contentHeight`).
        .frame(height: Self.headerRowHeight)
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

    /// Fixed height of the area between the header and footer, shared by the
    /// list, empty and error states.
    private static let contentHeight: CGFloat = 360

    /// Fixed height of the header row's controls, for the same reason as
    /// `contentHeight`.
    private static let headerRowHeight: CGFloat = 32

    private var content: some View {
        Group {
            let groups = store.matchesByCompetition
            // Set only when every Competition failed with nothing loaded.
            if let error = store.errorMessage {
                errorState(error)
            } else if groups.isEmpty {
                emptyState
            } else {
                // Fills the fixed area: short lists sit at the top, long ones
                // scroll.
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(groups, id: \.competition.id) { group in
                            competitionSection(group.competition, status: group.status,
                                               matches: group.matches)
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        // The MenuBarExtra window sizes itself to its content, and if it
        // resizes while open AppKit keeps its bottom edge fixed, so the top
        // drifts off the menu bar. A constant height (rather than one sized to
        // the content) prevents that. Non-list states are centred within it.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: Self.contentHeight)
    }

    /// A Competition's header, the note when its latest fetch failed, and its
    /// Matches. A Competition that failed to load has the header and note only.
    private func competitionSection(_ competition: Competition, status: CompetitionLoadStatus,
                                    matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(competition.displayName.uppercased())
                    .font(.caption2.weight(.semibold))
                if let note = competitionFailureNote(for: status) {
                    Text(note)
                        .font(.caption2)
                }
            }
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
                    ? "Nothing live or scheduled in your competitions today."
                    : "Nothing scheduled in your competitions that day.")
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
            SettingsButton()

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// The footer gear that opens the settings window (managed by
/// `SettingsWindowManager`, which floats it above other apps). While the window
/// is open the icon fills in and tints with the accent color; each open/close
/// spins it a half turn as a small "roll" flourish.
private struct SettingsButton: View {
    @EnvironmentObject private var settingsWindow: SettingsWindowManager
    /// Accumulated rotation, nudged on every open/close so the gear rolls each
    /// way rather than snapping.
    @State private var roll = 0.0

    var body: some View {
        Button {
            settingsWindow.toggle()
        } label: {
            Image(systemName: settingsWindow.isOpen ? "gearshape.fill" : "gearshape")
                .rotationEffect(.degrees(roll))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(settingsWindow.isOpen ? Color.accentColor : .secondary)
        .help("Settings")
        .onChange(of: settingsWindow.isOpen) { isOpen in
            withAnimation(.easeInOut(duration: 0.35)) {
                roll += isOpen ? 180 : -180
            }
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
        // Everything this row shows about the Match is decided outside the view.
        let presentation = MatchRowPresentation(match: match)
        HStack(alignment: .center, spacing: 8) {
            pinButton
            VStack(alignment: .leading, spacing: 2) {
                teamLine(match.home, isEmphasised: presentation.emphasisedTeam == .home)
                teamLine(match.away, isEmphasised: presentation.emphasisedTeam == .away)
            }
            .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                switch presentation.score {
                case .dash:
                    Text("—").foregroundStyle(.secondary)
                case let .goals(home, away):
                    Text(home).fontWeight(presentation.isLiveStyle ? .bold : .regular)
                    Text(away).fontWeight(presentation.isLiveStyle ? .bold : .regular)
                }
            }
            .font(.subheadline.monospacedDigit())
            statusBadge(presentation)
            if presentation.offersHighlights {
                highlightsButton
            }
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

    /// A team's logo and name. An emphasised team (a Penalty Shootout winner)
    /// has its name in bold; every other team stays regular weight.
    private func teamLine(_ team: Team, isEmphasised: Bool) -> some View {
        HStack(spacing: 6) {
            TeamLogoView(team: team)
            Text(team.name)
                .fontWeight(isEmphasised ? .bold : .regular)
                .lineLimit(1)
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

    /// Opens the fixture's YouTube highlights search in the default browser.
    /// Only rendered when the presentation offers highlights (see body).
    private var highlightsButton: some View {
        Button {
            NSWorkspace.shared.open(match.highlightsSearchURL)
        } label: {
            Image(systemName: "play.rectangle")
                .foregroundStyle(.secondary)
                .imageScale(.small)
        }
        .buttonStyle(.borderless)
        .help("Watch highlights")
    }

    private func statusBadge(_ presentation: MatchRowPresentation) -> some View {
        Text(presentation.badgeText)
            .font(.caption2)
            .foregroundStyle(presentation.isLiveStyle ? .white : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(presentation.isLiveStyle ? Color.red : Color.clear, in: Capsule())
            .frame(minWidth: 44, alignment: .trailing)
    }
}
