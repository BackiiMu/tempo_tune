package com.example.tempo_tune

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.*
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread
import kotlin.math.*

class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var micRequested=false
    private val rate = 48000
    data class Config(val bpm: Double=120.0,val beats: Int=4,val denominator: Int=4,val volume: Double=.7,val sound: String="wood",val muted: Set<Int> = emptySet(),val accent: Boolean=true)
    @Volatile private var config=Config()
    @Volatile private var outputRunning=false
    @Volatile private var inputRunning=false
    private var outputThread: Thread?=null
    private var inputThread: Thread?=null
    private var focusRequest: AudioFocusRequest?=null
    private val audioManager by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private val focusListener=AudioManager.OnAudioFocusChangeListener { change ->
        if(change<0) { stopAll(); emit(mapOf("type" to "stopped","reason" to "오디오 인터럽트로 정지했어요. 다시 시작해 주세요.")) }
    }
    private val routeCallback=object:AudioDeviceCallback(){
        override fun onAudioDevicesRemoved(devices:Array<out AudioDeviceInfo>){ if(outputRunning||inputRunning){stopAll();emit(mapOf("type" to "stopped","reason" to "오디오 연결이 변경되어 정지했어요."))} }
        override fun onAudioDevicesAdded(devices:Array<out AudioDeviceInfo>){ if(outputRunning||inputRunning){stopAll();emit(mapOf("type" to "stopped","reason" to "오디오 연결이 변경되어 정지했어요."))} }
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        audioManager.registerAudioDeviceCallback(routeCallback,main)
        EventChannel(engine.dartExecutor.binaryMessenger,"tempotune/events").setStreamHandler(object:EventChannel.StreamHandler{
            override fun onListen(arguments:Any?,events:EventChannel.EventSink){sink=events}
            override fun onCancel(arguments:Any?){sink=null;stopAll()}
        })
        MethodChannel(engine.dartExecutor.binaryMessenger,"tempotune/audio").setMethodCallHandler { call,result ->
            try { when(call.method){
                "configure"->{val a=call.arguments as Map<*,*>;config=Config((a["bpm"] as Number).toDouble().coerceIn(30.0,300.0),(a["beats"] as Number).toInt(),(a["denominator"] as Number).toInt(),(a["volume"] as Number).toDouble(),a["sound"] as String,(a["muted"] as List<*>).map{(it as Number).toInt()}.toSet(),a["accent"] as Boolean);result.success(null)}
                "start"->{startOutput();result.success(null)}
                "stop"->{stopOutput();result.success(null)}
                "startMic"->{micRequested=true;if(Build.VERSION.SDK_INT>=23&&checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){if(pendingPermission!=null)result.error("busy","권한 요청 중입니다",null) else {pendingPermission=result;requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),710)}}else{startInput();result.success(null)}}
                "stopMic"->{micRequested=false;stopInput();result.success(null)}
                "openSettings"->{startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:$packageName")));result.success(null)}
                else->result.notImplemented()
            }}catch(e:Exception){result.error("audio",e.localizedMessage,null)}
        }
    }
    private fun emit(event:Map<String,Any>){ main.post{sink?.success(event)} }
    private fun focus(){
        val status=if(Build.VERSION.SDK_INT>=26){
            focusRequest=AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()).setOnAudioFocusChangeListener(focusListener).build()
            audioManager.requestAudioFocus(focusRequest!!)
        }else{@Suppress("DEPRECATION") audioManager.requestAudioFocus(focusListener,AudioManager.STREAM_MUSIC,AudioManager.AUDIOFOCUS_GAIN)}
        check(status==AudioManager.AUDIOFOCUS_REQUEST_GRANTED){"오디오 사용 권한을 얻지 못했어요"}
    }
    private fun abandonFocus(){if(Build.VERSION.SDK_INT>=26)focusRequest?.let{audioManager.abandonAudioFocusRequest(it)}else{@Suppress("DEPRECATION") audioManager.abandonAudioFocus(focusListener)}}
    private fun click(frequency:Double,bright:Boolean):FloatArray=FloatArray(960){i->
        val t=i.toDouble()/rate
        ((sin(2*PI*frequency*t)+(if(bright).25*sin(2*PI*frequency*2.7*t) else 0.0))*exp(-t*(if(bright)380 else 240))).toFloat()
    }
    private fun startOutput(){
        stopAll();focus()
        val minBuffer=AudioTrack.getMinBufferSize(rate,AudioFormat.CHANNEL_OUT_MONO,AudioFormat.ENCODING_PCM_FLOAT)
        val track=AudioTrack.Builder().setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()).setAudioFormat(AudioFormat.Builder().setSampleRate(rate).setEncoding(AudioFormat.ENCODING_PCM_FLOAT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build()).setTransferMode(AudioTrack.MODE_STREAM).setBufferSizeInBytes(max(minBuffer,4096)).build()
        check(track.state==AudioTrack.STATE_INITIALIZED){"오디오 출력을 시작할 수 없어요"}
        val sounds=mapOf("wood" to arrayOf(click(1500.0,true),click(950.0,true)),"sine" to arrayOf(click(1000.0,false),click(650.0,false)),"bright" to arrayOf(click(2400.0,true),click(1600.0,true)))
        outputRunning=true
        outputThread=thread(name="TempoTune-output"){
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
            val clock=FrameClock();var clickPosition=960;var active=sounds["wood"]!![0];var gain=0.0
            val block=FloatArray(256)
            try{track.play();while(outputRunning){
                val c=config
                // BPM is quarter-note based; /8 meters emit eighth-note clicks.
                for(i in block.indices){
                    val beat=clock.next(c.bpm,c.beats,c.denominator)
                    if(beat!=null){val strong=c.accent&&FrameClock.strong(beat,c.denominator,c.beats);active=sounds[c.sound]!![if(strong)0 else 1];gain=if(c.muted.contains(beat))0.0 else c.volume*(if(strong)1.0 else .65);clickPosition=0;emit(mapOf("type" to "beat","beat" to beat))}
                    block[i]=if(clickPosition<active.size)(active[clickPosition++]*gain).toFloat() else 0f
                }
                var offset=0
                while(outputRunning&&offset<block.size){val n=track.write(block,offset,block.size-offset,AudioTrack.WRITE_BLOCKING);check(n>0){"오디오 출력 오류"};offset+=n}
            }}catch(e:Exception){emit(mapOf("type" to "stopped","reason" to (e.localizedMessage?:"오디오 출력 오류")))}finally{outputRunning=false;try{track.stop()}catch(_:Exception){};track.release()}
        }
    }
    private fun startInput(){
        stopAll();focus()
        val minimum=AudioRecord.getMinBufferSize(rate,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT)
        val inputSource=if(audioManager.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED)=="true") MediaRecorder.AudioSource.UNPROCESSED else MediaRecorder.AudioSource.MIC
        val recorder=AudioRecord(inputSource,rate,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT,max(minimum,32768))
        check(recorder.state==AudioRecord.STATE_INITIALIZED){"이 기기의 마이크를 시작할 수 없어요"}
        recorder.startRecording();inputRunning=true
        inputThread=thread(name="TempoTune-microphone"){
            val block=ShortArray(2048);val frame=ArrayList<Double>(4096);var sum=0.0;var count=0
            try{while(inputRunning){val n=recorder.read(block,0,block.size);check(n>0){"마이크 입력 오류"};for(i in 0 until n){sum+=block[i]/32768.0;count++;if(count==4){frame.add(sum/4);sum=0.0;count=0;if(frame.size==4096){emit(mapOf("type" to "pcm","samples" to frame.toList()));frame.clear()}}}}}catch(e:Exception){emit(mapOf("type" to "stopped","reason" to (e.localizedMessage?:"마이크 입력 오류")))}finally{inputRunning=false;try{recorder.stop()}catch(_:Exception){};recorder.release()}
        }
    }
    private fun stopOutput(){outputRunning=false;outputThread?.join(500);outputThread=null;if(!inputRunning)abandonFocus()}
    private fun stopInput(){inputRunning=false;inputThread?.join(500);inputThread=null;if(!outputRunning)abandonFocus()}
    private fun stopAll(){stopOutput();stopInput()}
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray){super.onRequestPermissionsResult(requestCode,permissions,grantResults);if(requestCode==710){val result=pendingPermission;pendingPermission=null;if(!micRequested){result?.error("cancelled","마이크 시작이 취소되었습니다",null)}else if(grantResults.firstOrNull()==PackageManager.PERMISSION_GRANTED){try{startInput();result?.success(null)}catch(e:Exception){result?.error("microphone",e.localizedMessage,null)}}else result?.error("permission","튜닝에는 마이크 권한이 필요해요. 앱 설정에서 허용해 주세요.",null)}}
    override fun onPause(){stopAll();super.onPause()}
    override fun onDestroy(){stopAll();audioManager.unregisterAudioDeviceCallback(routeCallback);super.onDestroy()}
}
