import SwiftUI

/// The app's global configuration window (the standard `Settings` scene):
/// refresh cadence and the menu bar live-indicator options. Team abbreviation
/// overrides are edited contextually from the popover rows, not here.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: MatchStore

    var body: some View {
        Form {
            Section("Refresh") {
                Picker("Update frequency", selection: $settings.cadence) {
                    ForEach(RefreshCadence.allCases, id: \.self) { cadence in
                        Text(cadence.displayName).tag(cadence)
                    }
                }
                Text(cadenceDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu bar") {
                Toggle("Show team logos", isOn: $settings.showTeamLogos)
                Toggle("Show live indicator", isOn: $settings.showLiveIndicator)
                Toggle("Include match minute", isOn: $settings.includeMatchMinute)
                    // Subordinate to the live indicator — the minute has no
                    // effect while the indicator is off.
                    .disabled(!settings.showLiveIndicator)
                    .padding(.leading, 16)
            }

            Section("Pinned match abbreviations") {
                if let match = store.pinnedSnapshot {
                    AbbreviationField(team: match.home)
                    AbbreviationField(team: match.away)
                    Text("Customize the codes shown for the pinned match in the menu bar and where a logo isn't available. Leave blank to use the default.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Pin a match to customize its menu bar abbreviations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Describes the selected cadence's live/idle intervals in seconds/minutes.
    private var cadenceDetail: String {
        let live = settings.cadence.liveInterval / 1_000_000_000
        let idleMinutes = settings.cadence.idleInterval / 60_000_000_000
        return "Live matches: every \(live)s · Otherwise: every \(idleMinutes) min"
    }
}

/// One editable abbreviation row for a team. Holds its own draft text (seeded
/// from any stored override) and writes through to `AppSettings` live, so the
/// menu bar title updates as you type; clearing the field resets to the ESPN
/// default. The placeholder shows that default.
private struct AbbreviationField: View {
    @EnvironmentObject private var settings: AppSettings
    let team: Team
    @State private var text = ""

    var body: some View {
        HStack {
            Text(team.name).lineLimit(1)
            Spacer(minLength: 8)
            TextField(team.abbreviation, text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .onChange(of: text) { settings.setAbbreviation($0, for: team) }
            Button("Reset") {
                settings.clearAbbreviation(for: team)
                text = ""
            }
            .disabled(!settings.hasOverride(for: team))
        }
        .onAppear { text = settings.abbreviationOverrides[team.id] ?? "" }
    }
}
