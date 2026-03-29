import UIKit
import MPVKit

class MpvPlayerView: UIView {
    private var mpv: OpaquePointer?
    private var glView: MPVOGLView?
    private var progressTimer: Timer?
    private var isInitialized = false
    private var pendingUri: String?
    private var pendingPaused = false
    private var pendingSeek: Double = -1

    // RN event callbacks
    var onMpvLoad: (([String: Any]) -> Void)?
    var onMpvProgress: (([String: Any]) -> Void)?
    var onMpvBuffer: (([String: Any]) -> Void)?
    var onMpvError: (([String: Any]) -> Void)?
    var onMpvEnd: (([String: Any]) -> Void)?
    var onMpvTracksChanged: (([String: Any]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setupMpv()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        setupMpv()
    }

    deinit {
        destroy()
    }

    private func setupMpv() {
        mpv = mpv_create()
        guard let ctx = mpv else { return }

        // Core configuration
        setMpvOption(ctx, "vo", "gpu")
        setMpvOption(ctx, "gpu-api", "opengl")
        setMpvOption(ctx, "hwdec", "videotoolbox")
        setMpvOption(ctx, "ao", "audiounit")
        setMpvOption(ctx, "demuxer-max-bytes", "150MiB")
        setMpvOption(ctx, "demuxer-max-back-bytes", "75MiB")
        setMpvOption(ctx, "cache", "yes")
        setMpvOption(ctx, "cache-secs", "120")
        setMpvOption(ctx, "network-timeout", "30")
        setMpvOption(ctx, "keep-open", "yes")
        setMpvOption(ctx, "profile", "fast")
        setMpvOption(ctx, "terminal", "no")
        setMpvOption(ctx, "msg-level", "all=warn")
        setMpvOption(ctx, "tls-verify", "no")
        setMpvOption(ctx, "ytdl", "no")

        // Initialize mpv
        let initResult = mpv_initialize(ctx)
        guard initResult == 0 else {
            onMpvError?(["error": "mpv_initialize failed: \(initResult)"])
            return
        }

        // Setup OpenGL rendering view
        let gl = MPVOGLView(frame: bounds)
        gl.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gl.initMpvGL(ctx)
        addSubview(gl)
        glView = gl

        // Observe properties
        mpv_observe_property(ctx, 0, "time-pos", MPV_FORMAT_DOUBLE)
        mpv_observe_property(ctx, 0, "duration", MPV_FORMAT_DOUBLE)
        mpv_observe_property(ctx, 0, "pause", MPV_FORMAT_FLAG)
        mpv_observe_property(ctx, 0, "paused-for-cache", MPV_FORMAT_FLAG)
        mpv_observe_property(ctx, 0, "track-list/count", MPV_FORMAT_INT64)
        mpv_observe_property(ctx, 0, "eof-reached", MPV_FORMAT_FLAG)

        // Setup event polling
        mpv_set_wakeup_callback(ctx, { pointer in
            guard let view = pointer.map({ Unmanaged<MpvPlayerView>.fromOpaque($0).takeUnretainedValue() }) else { return }
            DispatchQueue.main.async { view.handleEvents() }
        }, Unmanaged.passUnretained(self).toOpaque())

        isInitialized = true

        // Start progress timer
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.emitProgress()
        }

        // Load pending URI
        if let uri = pendingUri {
            loadFile(uri)
            pendingUri = nil
        }
    }

    private func setMpvOption(_ ctx: OpaquePointer, _ name: String, _ value: String) {
        mpv_set_option_string(ctx, name, value)
    }

    // MARK: - Public API

    func setUri(_ uri: String?) {
        guard let uri = uri, !uri.isEmpty else { return }
        if isInitialized {
            loadFile(uri)
        } else {
            pendingUri = uri
        }
    }

    func setUserAgent(_ userAgent: String?) {
        guard let ctx = mpv, let ua = userAgent else { return }
        mpv_set_option_string(ctx, "user-agent", ua)
    }

    func setPaused(_ paused: Bool) {
        pendingPaused = paused
        guard let ctx = mpv, isInitialized else { return }
        var flag: Int32 = paused ? 1 : 0
        mpv_set_property(ctx, "pause", MPV_FORMAT_FLAG, &flag)
    }

    func setStartPosition(_ seconds: Double) {
        if seconds > 0 {
            pendingSeek = seconds
        }
    }

    func seekTo(_ seconds: Double) {
        guard let ctx = mpv, isInitialized, seconds >= 0 else { return }
        let args = [seconds.description, "absolute"]
        mpvCommand(ctx, "seek", args)
    }

    func seekRelative(_ seconds: Double) {
        guard let ctx = mpv, isInitialized else { return }
        let args = [seconds.description, "relative"]
        mpvCommand(ctx, "seek", args)
    }

    func setAudioTrack(_ trackId: Int) {
        guard let ctx = mpv, isInitialized else { return }
        if trackId < 0 {
            mpv_set_option_string(ctx, "aid", "no")
        } else {
            var id = Int64(trackId)
            mpv_set_property(ctx, "aid", MPV_FORMAT_INT64, &id)
        }
    }

    func setSubtitleTrack(_ trackId: Int) {
        guard let ctx = mpv, isInitialized else { return }
        if trackId < 0 {
            mpv_set_option_string(ctx, "sid", "no")
        } else {
            var id = Int64(trackId)
            mpv_set_property(ctx, "sid", MPV_FORMAT_INT64, &id)
        }
    }

    func stop() {
        guard let ctx = mpv, isInitialized else { return }
        mpvCommand(ctx, "stop", [])
    }

    func destroy() {
        progressTimer?.invalidate()
        progressTimer = nil
        if let ctx = mpv {
            mpv_set_wakeup_callback(ctx, nil, nil)
            mpvCommand(ctx, "quit", [])
            mpv_terminate_destroy(ctx)
            mpv = nil
        }
        glView?.removeFromSuperview()
        glView = nil
        isInitialized = false
    }

    // MARK: - Private helpers

    private func loadFile(_ url: String) {
        guard let ctx = mpv else { return }
        mpvCommand(ctx, "loadfile", [url])
    }

    private func mpvCommand(_ ctx: OpaquePointer, _ name: String, _ args: [String]) {
        var cArgs: [UnsafeMutablePointer<CChar>?] = [strdup(name)]
        for arg in args {
            cArgs.append(strdup(arg))
        }
        cArgs.append(nil)
        mpv_command(ctx, &cArgs)
        for ptr in cArgs {
            free(ptr)
        }
    }

    private func handleEvents() {
        guard let ctx = mpv else { return }

        while true {
            let event = mpv_wait_event(ctx, 0)
            guard let ev = event?.pointee else { break }

            if ev.event_id == MPV_EVENT_NONE { break }

            switch ev.event_id {
            case MPV_EVENT_FILE_LOADED:
                handleFileLoaded()
            case MPV_EVENT_END_FILE:
                handleEndFile(ev)
            case MPV_EVENT_PROPERTY_CHANGE:
                handlePropertyChange(ev)
            case MPV_EVENT_LOG_MESSAGE:
                if let msg = ev.data?.assumingMemoryBound(to: mpv_event_log_message.self).pointee {
                    if msg.log_level <= MPV_LOG_LEVEL_ERROR.rawValue {
                        let text = String(cString: msg.text)
                        onMpvError?(["error": text])
                    }
                }
            default:
                break
            }
        }
    }

    private func handleFileLoaded() {
        guard let ctx = mpv else { return }
        var duration: Double = 0
        mpv_get_property(ctx, "duration", MPV_FORMAT_DOUBLE, &duration)

        var params: [String: Any] = ["duration": duration]
        let trackInfo = getTrackInfo()
        params["audioTracks"] = trackInfo.audio
        params["textTracks"] = trackInfo.text

        onMpvLoad?(params)

        // Apply pending state
        if pendingPaused {
            var flag: Int32 = 1
            mpv_set_property(ctx, "pause", MPV_FORMAT_FLAG, &flag)
        }
        if pendingSeek >= 0 {
            seekTo(pendingSeek)
            pendingSeek = -1
        }
    }

    private func handleEndFile(_ ev: mpv_event) {
        if let endFile = ev.data?.assumingMemoryBound(to: mpv_event_end_file.self).pointee {
            if endFile.error < 0 {
                onMpvError?(["error": "Playback error (code: \(endFile.error))"])
            } else {
                onMpvEnd?([:])
            }
        } else {
            onMpvEnd?([:])
        }
    }

    private func handlePropertyChange(_ ev: mpv_event) {
        guard let prop = ev.data?.assumingMemoryBound(to: mpv_event_property.self).pointee else { return }
        let name = String(cString: prop.name)

        switch name {
        case "paused-for-cache":
            if prop.format == MPV_FORMAT_FLAG, let data = prop.data {
                let flag = data.assumingMemoryBound(to: Int32.self).pointee
                onMpvBuffer?(["isBuffering": flag != 0])
            }
        case "eof-reached":
            if prop.format == MPV_FORMAT_FLAG, let data = prop.data {
                let flag = data.assumingMemoryBound(to: Int32.self).pointee
                if flag != 0 {
                    onMpvEnd?([:])
                }
            }
        case "track-list/count":
            let trackInfo = getTrackInfo()
            onMpvTracksChanged?([
                "audioTracks": trackInfo.audio,
                "textTracks": trackInfo.text
            ])
        default:
            break
        }
    }

    private func emitProgress() {
        guard let ctx = mpv, isInitialized else { return }
        var timePos: Double = 0
        var dur: Double = 0
        mpv_get_property(ctx, "time-pos", MPV_FORMAT_DOUBLE, &timePos)
        mpv_get_property(ctx, "duration", MPV_FORMAT_DOUBLE, &dur)

        if timePos > 0 || dur > 0 {
            onMpvProgress?([
                "currentTime": timePos,
                "duration": dur
            ])
        }
    }

    private func getTrackInfo() -> (audio: [[String: Any]], text: [[String: Any]]) {
        guard let ctx = mpv else { return ([], []) }
        var count: Int64 = 0
        mpv_get_property(ctx, "track-list/count", MPV_FORMAT_INT64, &count)

        var audio: [[String: Any]] = []
        var text: [[String: Any]] = []

        for i in 0..<Int(count) {
            guard let typeStr = getPropertyString(ctx, "track-list/\(i)/type") else { continue }
            var id: Int64 = 0
            mpv_get_property(ctx, "track-list/\(i)/id", MPV_FORMAT_INT64, &id)
            let title = getPropertyString(ctx, "track-list/\(i)/title") ?? ""
            let lang = getPropertyString(ctx, "track-list/\(i)/lang") ?? ""

            let name = title.isEmpty ? (lang.isEmpty ? "Track \(id)" : lang) : title
            let track: [String: Any] = ["id": Int(id), "name": name, "language": lang]

            switch typeStr {
            case "audio": audio.append(track)
            case "sub": text.append(track)
            default: break
            }
        }

        return (audio, text)
    }

    private func getPropertyString(_ ctx: OpaquePointer, _ name: String) -> String? {
        guard let cStr = mpv_get_property_string(ctx, name) else { return nil }
        let str = String(cString: cStr)
        mpv_free(cStr)
        return str
    }
}

// MARK: - MPVOGLView (OpenGL rendering surface)

class MPVOGLView: UIView {
    private var renderCtx: OpaquePointer?

    func initMpvGL(_ mpvCtx: OpaquePointer) {
        #if canImport(OpenGLES)
        // iOS/tvOS uses OpenGL ES via EAGLContext
        // MPVKit handles the GL context internally
        let params: [mpv_render_param] = [
            mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: UnsafeMutableRawPointer(mutating: MPV_RENDER_API_TYPE_OPENGL)),
            mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
        ]
        var ctx: OpaquePointer?
        mpv_render_context_create(&ctx, mpvCtx, params)
        renderCtx = ctx
        #endif
    }

    deinit {
        if let ctx = renderCtx {
            mpv_render_context_free(ctx)
        }
    }
}
