// koe-helper: streams on-device mic recognition via SpeechTranscriber as NDJSON on stdout.
// contract: {"e":"ready"} / {"e":"volatile","text":...} / {"e":"final","text":...} / {"e":"error","message":...}
// Stop by closing stdin (Neovim calls chanclose) -> finalize, then exit 0.
import AVFoundation
import Foundation
import Speech

struct Event: Encodable {
    let e: String
    var text: String? = nil
    var message: String? = nil
}

func emit(_ ev: Event) {
    let data = try! JSONEncoder().encode(ev)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
}

func fail(_ message: String) -> Never {
    emit(Event(e: "error", message: message))
    exit(1)
}

var localeID = "ja-JP"
var rest = CommandLine.arguments.dropFirst()
while let arg = rest.first {
    rest = rest.dropFirst()
    if arg == "--locale", let v = rest.first {
        localeID = v
        rest = rest.dropFirst()
    }
}

let locale = Locale(identifier: localeID)
let supported = await SpeechTranscriber.supportedLocales
guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
    fail("unsupported locale: \(localeID)")
}

guard await AVCaptureDevice.requestAccess(for: .audio) else {
    fail("microphone permission denied (TCC はターミナルアプリに帰属)")
}

let transcriber = SpeechTranscriber(
    locale: locale,
    transcriptionOptions: [],
    reportingOptions: [.volatileResults],
    attributeOptions: []
)

do {
    if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try await request.downloadAndInstall()
    }
} catch {
    fail("model install failed: \(error)")
}

guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
    fail("no compatible audio format")
}

let analyzer = SpeechAnalyzer(modules: [transcriber])
let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

let resultsTask = Task {
    do {
        for try await result in transcriber.results {
            emit(Event(e: result.isFinal ? "final" : "volatile", text: String(result.text.characters)))
        }
    } catch {
        emit(Event(e: "error", message: "\(error)"))
    }
}

do {
    try await analyzer.start(inputSequence: inputSequence)
} catch {
    fail("analyzer start failed: \(error)")
}

let engine = AVAudioEngine()
let input = engine.inputNode
let inputFormat = input.outputFormat(forBus: 0)
guard let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
    fail("audio converter init failed")
}

input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
    let ratio = analyzerFormat.sampleRate / inputFormat.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
    guard let out = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }
    var served = false
    var convError: NSError?
    let status = converter.convert(to: out, error: &convError) { _, outStatus in
        if served {
            outStatus.pointee = .noDataNow
            return nil
        }
        served = true
        outStatus.pointee = .haveData
        return buffer
    }
    if status != .error, out.frameLength > 0 {
        inputBuilder.yield(AnalyzerInput(buffer: out))
    }
}

do {
    engine.prepare()
    try engine.start()
} catch {
    fail("audio engine start failed: \(error)")
}

emit(Event(e: "ready"))

// ponytail: stdin EOF is the only graceful stop; SIGTERM keeps its default (kill), losing only the trailing final.
await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
    DispatchQueue.global().async {
        while readLine(strippingNewline: false) != nil {}
        cont.resume()
    }
}

engine.stop()
inputBuilder.finish()
try? await analyzer.finalizeAndFinishThroughEndOfInput()
_ = await resultsTask.value
exit(0)
