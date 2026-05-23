import Combine
import Foundation
import QuartzCore

@MainActor
final class PVTTestViewModel: ObservableObject {
    enum Phase: Equatable {
        case waiting
        case stimulus(startTime: CFTimeInterval)
        case completed(PVTSummary)
    }

    @Published private(set) var phase: Phase = .waiting
    @Published private(set) var trials: [PVTTrial] = []
    @Published private(set) var currentElapsedMilliseconds = 0
    @Published private(set) var isShowingFalseStart = false
    @Published private(set) var isShowingSlowLapse = false

    let totalTrials: Int
    let lapseThresholdMilliseconds: Int
    let excludesLapsesFromAverage: Bool
    let autoLapseMilliseconds: Int

    private let delayRange: ClosedRange<Double>
    private var stimulusTimer: DispatchSourceTimer?
    private var stimulusTimeoutTimer: DispatchSourceTimer?
    private var waitingStimulusFireTime: CFTimeInterval?
    private var stimulusTimeoutFireTime: CFTimeInterval?
    private var pausedState: PausedState?

    private enum PausedState {
        case waiting(remainingDelay: CFTimeInterval)
        case stimulus(elapsed: CFTimeInterval, remainingTimeout: CFTimeInterval)
    }

    init(
        totalTrials: Int = 7,
        lapseThresholdMilliseconds: Int = 500,
        excludesLapsesFromAverage: Bool = true,
        autoLapseMilliseconds: Int = 5000,
        delayRange: ClosedRange<Double> = 2...10
    ) {
        self.totalTrials = totalTrials
        self.lapseThresholdMilliseconds = lapseThresholdMilliseconds
        self.excludesLapsesFromAverage = excludesLapsesFromAverage
        self.autoLapseMilliseconds = autoLapseMilliseconds
        self.delayRange = delayRange
    }

    var completedTrialCount: Int {
        trials.count
    }

    var bestMilliseconds: Int? {
        trials.map(\.reactionTimeMilliseconds).min()
    }

    var averageMilliseconds: Int? {
        summary.averageMilliseconds
    }

    var lapseCount: Int {
        summary.lapseCount
    }

    var summary: PVTSummary {
        PVTSummary(
            trials: trials,
            lapseThresholdMilliseconds: lapseThresholdMilliseconds,
            excludesLapsesFromAverage: excludesLapsesFromAverage
        )
    }

    func start() {
        trials = []
        currentElapsedMilliseconds = 0
        isShowingFalseStart = false
        isShowingSlowLapse = false
        phase = .waiting
        scheduleNextStimulus()
    }

    func stop() {
        stimulusTimer?.cancel()
        stimulusTimer = nil
        waitingStimulusFireTime = nil
        stopStimulusTimeoutTimer()
        pausedState = nil
    }

    func pause() {
        guard pausedState == nil else {
            return
        }

        let now = CACurrentMediaTime()

        switch phase {
        case .waiting:
            let remainingDelay = max(0.2, (waitingStimulusFireTime ?? now) - now)
            stimulusTimer?.cancel()
            stimulusTimer = nil
            waitingStimulusFireTime = nil
            pausedState = .waiting(remainingDelay: remainingDelay)

        case let .stimulus(startTime):
            let elapsed = max(0, now - startTime)
            let remainingTimeout = max(0.2, (stimulusTimeoutFireTime ?? now) - now)
            stopStimulusTimeoutTimer()
            pausedState = .stimulus(elapsed: elapsed, remainingTimeout: remainingTimeout)

        case .completed:
            break
        }
    }

    func resume() {
        guard let pausedState else {
            return
        }

        self.pausedState = nil

        switch pausedState {
        case let .waiting(remainingDelay):
            scheduleNextStimulus(after: remainingDelay)

        case let .stimulus(elapsed, remainingTimeout):
            let adjustedStartTime = CACurrentMediaTime() - elapsed
            phase = .stimulus(startTime: adjustedStartTime)
            scheduleStimulusTimeout(after: remainingTimeout)
        }
    }

    func updateElapsed(now: CFTimeInterval = CACurrentMediaTime()) {
        guard case let .stimulus(startTime) = phase else {
            return
        }

        currentElapsedMilliseconds = max(0, Int(((now - startTime) * 1000).rounded()))
    }

    func handleTap(at touchTime: CFTimeInterval = CACurrentMediaTime()) {
        guard case let .stimulus(startTime) = phase else {
            registerFalseStartIfNeeded()
            return
        }

        isShowingFalseStart = false
        isShowingSlowLapse = false
        stopStimulusTimeoutTimer()
        let milliseconds = max(0, Int(((touchTime - startTime) * 1000).rounded()))
        let trial = PVTTrial(
            index: trials.count + 1,
            reactionTimeMilliseconds: milliseconds,
            isLapse: milliseconds > lapseThresholdMilliseconds
        )
        let updatedTrials = trials + [trial]
        trials = updatedTrials
        currentElapsedMilliseconds = milliseconds

        if updatedTrials.count >= totalTrials {
            stop()
            phase = .completed(summary)
        } else {
            phase = .waiting
            scheduleNextStimulus()
        }
    }

    private func registerFalseStartIfNeeded() {
        guard case .waiting = phase else {
            return
        }

        isShowingFalseStart = true
        isShowingSlowLapse = false
        currentElapsedMilliseconds = 0
        phase = .waiting
        scheduleNextStimulus()
    }

    private func recordAutoLapse() {
        guard case .stimulus = phase else {
            return
        }

        stopStimulusTimeoutTimer()

        let trial = PVTTrial(
            index: trials.count + 1,
            reactionTimeMilliseconds: autoLapseMilliseconds,
            isLapse: true
        )
        let updatedTrials = trials + [trial]
        trials = updatedTrials
        currentElapsedMilliseconds = autoLapseMilliseconds
        isShowingFalseStart = false
        isShowingSlowLapse = true

        if updatedTrials.count >= totalTrials {
            stop()
            phase = .completed(summary)
        } else {
            phase = .waiting
            scheduleNextStimulus()
        }
    }

    private func scheduleNextStimulus() {
        let delay = Double.random(in: delayRange)
        scheduleNextStimulus(after: delay)
    }

    private func scheduleNextStimulus(after delay: CFTimeInterval) {
        stop()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay, leeway: .milliseconds(1))
        waitingStimulusFireTime = CACurrentMediaTime() + delay
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            let startTime = CACurrentMediaTime()
            self.isShowingFalseStart = false
            self.isShowingSlowLapse = false
            self.currentElapsedMilliseconds = 0
            self.phase = .stimulus(startTime: startTime)
            self.stimulusTimer?.cancel()
            self.stimulusTimer = nil
            self.waitingStimulusFireTime = nil
            self.scheduleStimulusTimeout()
        }
        stimulusTimer = timer
        timer.resume()
    }

    private func scheduleStimulusTimeout() {
        scheduleStimulusTimeout(after: CFTimeInterval(autoLapseMilliseconds) / 1000)
    }

    private func scheduleStimulusTimeout(after delay: CFTimeInterval) {
        stopStimulusTimeoutTimer()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay, leeway: .milliseconds(1))
        stimulusTimeoutFireTime = CACurrentMediaTime() + delay
        timer.setEventHandler { [weak self] in
            self?.recordAutoLapse()
        }
        stimulusTimeoutTimer = timer
        timer.resume()
    }

    private func stopStimulusTimeoutTimer() {
        stimulusTimeoutTimer?.cancel()
        stimulusTimeoutTimer = nil
        stimulusTimeoutFireTime = nil
    }
}
