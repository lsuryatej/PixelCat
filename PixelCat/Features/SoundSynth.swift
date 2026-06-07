import AVFoundation

/// Generates the cat's sounds procedurally at runtime (no bundled audio files).
/// A short pitch-bent "meow" one-shot and a low, loopable "purr" rumble.
final class SoundSynth {
    private let engine = AVAudioEngine()
    private let meowNode = AVAudioPlayerNode()
    private let purrNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private lazy var meowBuffer: AVAudioPCMBuffer = makeMeow()
    private lazy var meowLongBuffer: AVAudioPCMBuffer = makeMeowLong()
    private lazy var purrBuffer: AVAudioPCMBuffer = makePurr()

    private var started = false
    private var purring = false

    init() {
        engine.attach(meowNode)
        engine.attach(purrNode)
        engine.connect(meowNode, to: engine.mainMixerNode, format: format)
        engine.connect(purrNode, to: engine.mainMixerNode, format: format)
    }

    private func ensureRunning() {
        guard !started else { return }
        do { try engine.start(); started = true } catch { /* audio is best-effort */ }
    }

    // MARK: Public

    func meow() {
        ensureRunning()
        meowNode.scheduleBuffer(meowBuffer, at: nil, options: .interrupts, completionHandler: nil)
        meowNode.play()
    }

    /// A longer, more drawn-out "meoww" for announcements (timer phase change,
    /// agent done, stretch) so it's clearly distinct from the short click meow.
    func longMeow() {
        ensureRunning()
        meowNode.scheduleBuffer(meowLongBuffer, at: nil, options: .interrupts, completionHandler: nil)
        meowNode.play()
    }

    func startPurr() {
        guard !purring else { return }
        purring = true
        ensureRunning()
        purrNode.scheduleBuffer(purrBuffer, at: nil, options: .loops, completionHandler: nil)
        purrNode.play()
    }

    func stopPurr() {
        guard purring else { return }
        purring = false
        purrNode.stop()
    }

    // MARK: Synthesis

    private func makeMeow() -> AVAudioPCMBuffer {
        let sr = Float(format.sampleRate)
        let dur: Float = 0.55
        let n = AVAudioFrameCount(sr * dur)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        buf.frameLength = n
        let out = buf.floatChannelData![0]

        var phase: Float = 0
        for i in 0..<Int(n) {
            let t = Float(i) / sr
            let p = t / dur                                  // 0…1 progress
            // Pitch: rise then fall, with vibrato — the "me-ow" contour.
            let base: Float = 520 + 360 * sin(Float.pi * min(p * 1.2, 1))
            let vibrato: Float = 18 * sin(2 * .pi * 6 * t)
            let freq = base + vibrato
            phase += 2 * .pi * freq / sr
            // A couple of harmonics give it a vocal, nasal timbre.
            let s = sin(phase) * 0.6 + sin(phase * 2) * 0.25 + sin(phase * 3) * 0.12
            // Envelope: quick attack, gentle decay.
            let env = expEnv(p, attack: 0.06, release: 0.5)
            out[i] = s * env * 0.28
        }
        return buf
    }

    private func makeMeowLong() -> AVAudioPCMBuffer {
        let sr = Float(format.sampleRate)
        let dur: Float = 1.05
        let n = AVAudioFrameCount(sr * dur)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        buf.frameLength = n
        let out = buf.floatChannelData![0]

        var phase: Float = 0
        for i in 0..<Int(n) {
            let t = Float(i) / sr
            let p = t / dur
            // Two-swell, wavy "me-oww" contour with vibrato — longer tail.
            let base: Float = 520 + 220 * sin(.pi * p) + 80 * sin(.pi * 3 * p)
            let vibrato: Float = 16 * sin(2 * .pi * 5.5 * t)
            let freq = base + vibrato
            phase += 2 * .pi * freq / sr
            let s = sin(phase) * 0.6 + sin(phase * 2) * 0.25 + sin(phase * 3) * 0.12
            let env = expEnv(p, attack: 0.05, release: 0.62)
            out[i] = s * env * 0.30
        }
        return buf
    }

    private func makePurr() -> AVAudioPCMBuffer {
        let sr = Float(format.sampleRate)
        // Loop length = whole number of modulation cycles for seamless looping.
        let modHz: Float = 26
        let cycles: Float = 13
        let dur = cycles / modHz
        let n = AVAudioFrameCount(sr * dur)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        buf.frameLength = n
        let out = buf.floatChannelData![0]

        for i in 0..<Int(n) {
            let t = Float(i) / sr
            let carrier = sin(2 * .pi * 55 * t) * 0.7 + sin(2 * .pi * 110 * t) * 0.3
            let am = 0.45 + 0.55 * (0.5 + 0.5 * sin(2 * .pi * modHz * t))  // rumble
            out[i] = carrier * am * 0.13
        }
        return buf
    }

    private func expEnv(_ p: Float, attack: Float, release: Float) -> Float {
        if p < attack { return p / attack }
        let r = (p - attack) / max(release, 0.001)
        return exp(-3 * r)
    }
}
