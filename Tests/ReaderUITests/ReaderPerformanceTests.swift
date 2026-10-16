import AppKit
import Testing
@testable import UnagiReader

@MainActor struct ReaderPerformanceTests {
    @Test func launchNeedsVisibleRowsAndKeepsTheFirstDraw() {
        var launch = ReaderPerformance.Launch()
        let start = Date(timeIntervalSince1970: 100)
        launch.drawn(rows: 0, visible: true, processStart: start, at: start.addingTimeInterval(0.4))
        launch.drawn(rows: 10, visible: false, processStart: start, at: start.addingTimeInterval(0.5))
        #expect(launch.milliseconds == nil)
        launch.drawn(rows: 10, visible: true, processStart: start, at: start.addingTimeInterval(0.75))
        launch.drawn(rows: 10, visible: true, processStart: start, at: start.addingTimeInterval(2))
        #expect(launch.milliseconds == 750)
    }

    @Test func aMissingProcessTimestampCannotPassTheLaunchBudget() {
        var launch = ReaderPerformance.Launch()
        launch.drawn(rows: 10, visible: true, processStart: nil, at: .now)
        #expect(launch.milliseconds == nil)
        let start = ReaderPerformance.processStart()
        #expect(start != nil && start! <= Date.now)
    }

    @Test func theHeartbeatSubtractsItsExpectedTwentyMilliseconds() {
        #expect(ReaderPerformance.schedulingGap(previous: nil, now: 1) == nil)
        #expect(ReaderPerformance.schedulingGap(previous: 0, now: 0.12) == nil)
        #expect(abs(ReaderPerformance.schedulingGap(previous: 0, now: 0.13)! - 110) < 0.001)
    }
}
