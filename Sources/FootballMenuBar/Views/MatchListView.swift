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

    private var header: some View {
        HStack {
            Label("Football", systemImage: "soccerball")
                .font(.headline)
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
            .disabled(store.isRefreshing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

    private var emptyState: some View {
        stateMessage(icon: "calendar",
                     title: "No matches right now",
                     subtitle: "Nothing live or scheduled in your leagues today.")
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
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// A single match row: a pin control, each team with its logo, the score on the
/// right, and a status badge.
private struct MatchRow: View {
    @EnvironmentObject private var store: MatchStore
    let match: Match

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
    }

    private func teamLine(_ team: Team) -> some View {
        HStack(spacing: 6) {
            TeamLogoView(team: team)
            Text(team.name).lineLimit(1)
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
