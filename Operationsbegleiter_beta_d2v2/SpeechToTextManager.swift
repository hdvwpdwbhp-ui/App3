import SwiftUI
import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechToTextManager {

    private let audioEngine = AVAudioEngine()

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    private var onStatus: ((Bool) -> Void)?
    private var onText: ((String) -> Void)?
    private var onError: ((String) -> Void)?

    func start(
        locale: Locale = Locale(identifier: "de-DE"),
        onStatus: @escaping (Bool) -> Void,
        onText: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.onStatus = onStatus
        self.onText = onText
        self.onError = onError

        stop()

        recognizer = SFSpeechRecognizer(locale: locale)

        guard let recognizer else {
            onError("Spracherkennung nicht verfügbar.")
            onStatus(false)
            return
        }

        guard recognizer.isAvailable else {
            onError("Spracherkennung aktuell nicht verfügbar.")
            onStatus(false)
            return
        }

        Task {
            let ok = await requestPermissions()
            guard ok else {
                self.onError?("Berechtigung für Mikrofon/Spracherkennung fehlt.")
                self.onStatus?(false)
                return
            }

            do {
                try await startEngineAndRecognition(with: recognizer)
                self.onStatus?(true)
            } catch {
                self.onError?("Speech-to-Text Fehler: \(error.localizedDescription)")
                self.onStatus?(false)
                self.stop()
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        request = nil

        task?.cancel()
        task = nil
    }

    private func requestPermissions() async -> Bool {
        let speechAuth: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechAuth else { return false }

        let micAuth: Bool = await withCheckedContinuation { cont in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }

        return micAuth
    }

    private func startEngineAndRecognition(with recognizer: SFSpeechRecognizer) async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.onText?(result.bestTranscription.formattedString)

                if result.isFinal {
                    self.onStatus?(false)
                    self.stop()
                }
            }

            if let error {
                self.onError?("Spracherkennung: \(error.localizedDescription)")
                self.onStatus?(false)
                self.stop()
            }
        }
    }
}
