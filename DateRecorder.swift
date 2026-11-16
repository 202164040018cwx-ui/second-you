import Foundation
import AVFoundation
import Speech

/// Records a date with the phone's microphone and transcribes it on the device.
/// Nothing starts until both people have agreed, and no audio is kept: only the transcript.
@MainActor
final class DateRecorder: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var transcript = ""
    @Published private(set) var status = "Ready"
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var earlier = ""      // text from finished recognition segments
    private var started = Date()
    private var timer: Timer?

    func start() async {
        guard !recording else { return }
        let speech = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
        guard speech == .authorized else { status = "Allow speech recognition in Settings"; return }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else { status = "Allow the microphone in Settings"; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else { status = "Speech recognition isn't available right now"; return }
        self.recognizer = recognizer
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
                let level = Self.rms(buffer)
                Task { @MainActor in self?.level = level }
            }
            engine.prepare()
            try engine.start()
        } catch {
            status = "Couldn't start the microphone"
            return
        }
        transcript = ""; earlier = ""; elapsed = 0; started = Date()
        recording = true; status = "Recording · on this iPhone only"
        beginSegment()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self else { return }; self.elapsed = Date().timeIntervalSince(self.started) }
        }
    }

    /// Speech recognition ends a request after about a minute, so a long date is split into segments.
    private func beginSegment() {
        guard recording, let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        request.addsPunctuation = true
        self.request = request
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.transcript = [self.earlier, text].filter { !$0.isEmpty }.joined(separator: " ")
                    if result.isFinal { self.earlier = self.transcript; self.restart() }
                } else if error != nil {
                    self.earlier = self.transcript; self.restart()
                }
            }
        }
    }

    private func restart() {
        guard recording else { return }
        request?.endAudio(); task?.cancel()
        beginSegment()
    }

    func stop() {
        guard recording else { return }
        recording = false
        timer?.invalidate(); timer = nil
        engine.stop(); engine.inputNode.removeTap(onBus: 0)
        request?.endAudio(); task?.finish()
        request = nil; task = nil; level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        status = transcript.isEmpty ? "Nothing was heard" : "Saved the transcript. The audio was not kept."
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
        return min(1, sqrt(sum / Float(buffer.frameLength)) * 12)
    }
}
