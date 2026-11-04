import Testing
@testable import FootballMenuBar

@Suite("Competition failure note")
struct CompetitionFailureNoteTests {
    @Test("A stale Competition says it is showing its last results")
    func stale() {
        #expect(competitionFailureNote(for: .stale) == "Couldn't update, showing last results")
    }

    @Test("A Competition that failed to load says it couldn't load")
    func failedToLoad() {
        #expect(competitionFailureNote(for: .failedToLoad) == "Couldn't load")
    }

    @Test("A loaded Competition has no note")
    func loaded() {
        #expect(competitionFailureNote(for: .loaded) == nil)
    }
}
