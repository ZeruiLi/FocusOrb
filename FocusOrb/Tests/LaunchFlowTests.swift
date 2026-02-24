import XCTest
@testable import FocusOrb

final class LaunchFlowTests: XCTestCase {
    func testFirstLaunchRoutesToFirstLaunchAssist() {
        let destination = OrbWindowManager.launchDestination(
            currentState: .idle,
            hasSeenOnboarding: false,
            showOrbOnLaunch: true
        )

        XCTAssertEqual(destination, .firstLaunchAssist)
    }

    func testIdleWithShowOrbOnLaunchRoutesToStartAndShowOrb() {
        let destination = OrbWindowManager.launchDestination(
            currentState: .idle,
            hasSeenOnboarding: true,
            showOrbOnLaunch: true
        )

        XCTAssertEqual(destination, .startAndShowOrb)
    }

    func testIdleWithShowOrbDisabledRoutesToStartOnly() {
        let destination = OrbWindowManager.launchDestination(
            currentState: .idle,
            hasSeenOnboarding: true,
            showOrbOnLaunch: false
        )

        XCTAssertEqual(destination, .startOnly)
    }

    func testResumingSessionRoutesToResumeAndShowOrb() {
        let destination = OrbWindowManager.launchDestination(
            currentState: .green(startTime: Date()),
            hasSeenOnboarding: true,
            showOrbOnLaunch: false
        )

        XCTAssertEqual(destination, .resumeAndShowOrb)
    }

    func testFirstLaunchPolicyShowsOrbAndAllowsClosingStart() {
        let policy = OrbWindowManager.startPresentationPolicy(for: .firstLaunchAssist)

        XCTAssertEqual(
            policy,
            StartPresentationPolicy(hideOrbBeforeShow: false, allowClose: true)
        )
    }

    func testStartOnlyPolicyHidesOrbAndKeepsStartNonClosable() {
        let policy = OrbWindowManager.startPresentationPolicy(for: .startOnly)

        XCTAssertEqual(
            policy,
            StartPresentationPolicy(hideOrbBeforeShow: true, allowClose: false)
        )
    }
}
