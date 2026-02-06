import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var lastURL: URL?

    private var recorder: AVAudioRecorder?

    func start() {
        requestMicPermission { granted in
            guard granted else { return }

            // Wir sind hier in einem @Sendable completion -> zurück auf MainActor
            Task { @MainActor in
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                    try session.setActive(true)

                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec.m4a")
                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]

                    let r = try AVAudioRecorder(url: url, settings: settings)
                    r.prepareToRecord()
                    r.record()

                    self.recorder = r
                    self.isRecording = true
                    self.lastURL = url
                } catch {
                    print("AudioRecorder start error:", error)
                    self.isRecording = false
                }
            }
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        isRecording = false
    }

    private func requestMicPermission(_ completion: @escaping @Sendable (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: completion)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        }
    }
}
