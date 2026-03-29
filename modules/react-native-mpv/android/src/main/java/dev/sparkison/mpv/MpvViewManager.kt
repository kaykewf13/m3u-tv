package dev.sparkison.mpv

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp

class MpvViewManager : SimpleViewManager<MpvPlayerView>() {

    companion object {
        const val REACT_CLASS = "MpvPlayerView"

        // Command constants matching JS side
        const val COMMAND_SEEK_TO = 1
        const val COMMAND_SEEK_RELATIVE = 2
        const val COMMAND_SET_AUDIO_TRACK = 3
        const val COMMAND_SET_SUBTITLE_TRACK = 4
        const val COMMAND_STOP = 5
    }

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): MpvPlayerView {
        return MpvPlayerView(reactContext)
    }

    override fun onDropViewInstance(view: MpvPlayerView) {
        view.destroy()
        super.onDropViewInstance(view)
    }

    @ReactProp(name = "uri")
    fun setUri(view: MpvPlayerView, uri: String?) {
        view.setUri(uri)
    }

    @ReactProp(name = "userAgent")
    fun setUserAgent(view: MpvPlayerView, userAgent: String?) {
        view.setUserAgent(userAgent)
    }

    @ReactProp(name = "paused")
    fun setPaused(view: MpvPlayerView, paused: Boolean) {
        view.setPaused(paused)
    }

    override fun getExportedCustomDirectEventTypeConstants(): Map<String, Any> {
        return MapBuilder.builder<String, Any>()
            .put("onMpvLoad", MapBuilder.of("registrationName", "onMpvLoad"))
            .put("onMpvProgress", MapBuilder.of("registrationName", "onMpvProgress"))
            .put("onMpvBuffer", MapBuilder.of("registrationName", "onMpvBuffer"))
            .put("onMpvError", MapBuilder.of("registrationName", "onMpvError"))
            .put("onMpvEnd", MapBuilder.of("registrationName", "onMpvEnd"))
            .put("onMpvTracksChanged", MapBuilder.of("registrationName", "onMpvTracksChanged"))
            .build()
    }

    override fun getCommandsMap(): Map<String, Int> {
        return mapOf(
            "seekTo" to COMMAND_SEEK_TO,
            "seekRelative" to COMMAND_SEEK_RELATIVE,
            "setAudioTrack" to COMMAND_SET_AUDIO_TRACK,
            "setSubtitleTrack" to COMMAND_SET_SUBTITLE_TRACK,
            "stop" to COMMAND_STOP,
        )
    }

    override fun receiveCommand(view: MpvPlayerView, commandId: String?, args: ReadableArray?) {
        when (commandId) {
            "seekTo" -> {
                val seconds = args?.getDouble(0) ?: return
                view.seekTo(seconds)
            }
            "seekRelative" -> {
                val seconds = args?.getDouble(0) ?: return
                view.seekRelative(seconds)
            }
            "setAudioTrack" -> {
                val trackId = args?.getInt(0) ?: return
                view.setAudioTrack(trackId)
            }
            "setSubtitleTrack" -> {
                val trackId = args?.getInt(0) ?: return
                view.setSubtitleTrack(trackId)
            }
            "stop" -> view.stop()
        }
    }
}
