import AVFoundation
import Combine

/// Minimal audio engine for ambient atmosphere and interaction feedback.
/// Uses AVAudioEngine with generated tones — no asset files required.
final class AudioEngine: ObservableObject {

    private var audioEngine: AVAudioEngine?
    private var ambienceNode: AVAudioPlayerNode?
    private var ambienceBuffer: AVAudioPCMBuffer?
    private var isRunning = false

    init() {
        configureSession()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
    }

    // MARK: - Ambient drone

    func startAmbience() {
        guard !isRunning else { return }

        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        let sampleRate = 44100.0
        let duration = 4.0  // loop length in seconds
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return }

        buffer.frameLength = frameCount

        // Generate a soft low drone with overtones
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                let base = sin(2 * .pi * 55 * t) * 0.03          // A1
                let harm1 = sin(2 * .pi * 82.5 * t) * 0.015      // E2
                let harm2 = sin(2 * .pi * 110 * t) * 0.008        // A2
                let lfo = sin(2 * .pi * 0.15 * t) * 0.5 + 0.5    // slow volume swell
                let env = min(1.0, min(t / 1.0, (duration - t) / 1.0)) // fade in/out
                data[i] = Float((base + harm1 + harm2) * lfo * env)
            }
        }

        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.4

        do {
            try engine.start()
            playerNode.play()
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            self.audioEngine = engine
            self.ambienceNode = playerNode
            self.ambienceBuffer = buffer
            self.isRunning = true
        } catch {
            // Audio is non-critical; silently continue without it
        }
    }

    func stop() {
        ambienceNode?.stop()
        audioEngine?.stop()
        isRunning = false
    }

    // MARK: - Interaction sounds (short procedural tones)

    func playPlant() {
        playTone(frequency: 330, duration: 0.15, volume: 0.12)  // E4 — gentle "plop"
    }

    func playInteract() {
        playTone(frequency: 440, duration: 0.08, volume: 0.08)  // A4 — soft tap
    }

    /// Play a short sine-wave tone on a one-shot player node
    private func playTone(frequency: Double, duration: Double, volume: Float) {
        guard let engine = audioEngine, isRunning else { return }

        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return }

        buffer.frameLength = frameCount
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                let env = min(1.0, min(t / 0.005, (duration - t) / (duration * 0.6)))
                data[i] = Float(sin(2 * .pi * frequency * t) * Double(volume) * env)
            }
        }

        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        node.play()
        node.scheduleBuffer(buffer) {
            DispatchQueue.main.async {
                engine.disconnectNodeOutput(node)
                engine.detach(node)
            }
        }
    }
}
