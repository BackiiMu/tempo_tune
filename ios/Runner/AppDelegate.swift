import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audio: TempoAudio?
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TempoAudio")!
    audio = TempoAudio(messenger: registrar.messenger())
  }
}

final class TempoAudio: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var engine: AVAudioEngine?
  private var source: AVAudioSourceNode?
  private let lock = NSLock()
  private let analysis = DispatchQueue(label: "tempotune.pcm", qos: .userInitiated)
  private var bpm = 120.0, beats = 4, denominator = 4, volume = 0.7
  private var sound = "wood", muted = Set<Int>(), accent = true
  private var generation = 0
  private var micActive = false
  private var micPending = false
  private var frame = [Double](), phase = 0.0, sum = 0.0, count = 0
  init(messenger: FlutterBinaryMessenger) {
    super.init()
    let channel = FlutterMethodChannel(name: "tempotune/audio", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    FlutterEventChannel(name: "tempotune/events", binaryMessenger: messenger).setStreamHandler(self)
    NotificationCenter.default.addObserver(self, selector: #selector(interrupt), name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(route), name: AVAudioSession.routeChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(configurationChanged), name: .AVAudioEngineConfigurationChange, object: nil)
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { stop(); sink = nil; return nil }
  private func emit(_ event: [String: Any]) { DispatchQueue.main.async { [weak self] in self?.sink?(event) } }
  @objc private func configurationChanged(_ note: Notification) {
    // AVAudioEngine may notify synchronously during start. Never tear it down
    // reentrantly from that notification: doing so can deadlock CoreAudio.
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let engine = self.engine,
            let changed = note.object as? AVAudioEngine,
            engine === changed, !engine.isRunning else { return }
      self.stop(); self.emit(["type":"stopped", "reason":"오디오 구성이 변경되었어요. 다시 시작해 주세요."])
    }
  }
  @objc private func interrupt(_ note: Notification) {
    if note.name == AVAudioSession.interruptionNotification,
       let kind = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
       kind != AVAudioSession.InterruptionType.began.rawValue { return }
    guard engine != nil else { return }
    stop(); emit(["type":"stopped", "reason":"오디오 인터럽트로 정지했어요. 다시 시작해 주세요."])
  }
  @objc private func route(_ note: Notification) {
    guard let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
          reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue || reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue,
          engine != nil else { return }
    stop(); emit(["type":"stopped", "reason":"오디오 연결이 변경되어 정지했어요."])
  }
  @objc private func background() { stop() }
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "configure":
        let args = call.arguments as! [String: Any]
        lock.lock()
        bpm = (args["bpm"] as! NSNumber).doubleValue; beats = args["beats"] as! Int
        denominator = args["denominator"] as! Int; volume = (args["volume"] as! NSNumber).doubleValue
        sound = args["sound"] as! String; muted = Set(args["muted"] as! [Int]); accent = args["accent"] as! Bool
        lock.unlock(); result(nil)
      case "start": try startOutput(); result(nil)
      case "stop": if !micActive { stop() }; result(nil)
      case "stopMic": if micActive || micPending { stop() }; result(nil)
      case "startMic":
        micPending = true
        let requestGeneration = generation
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
          DispatchQueue.main.async {
            guard let self = self else { return }
            guard self.micPending && self.generation == requestGeneration else { result(FlutterError(code:"cancelled",message:"마이크 시작이 취소되었습니다",details:nil)); return }
            self.micPending = false
            guard granted else { result(FlutterError(code:"permission",message:"튜닝에는 마이크 권한이 필요해요. 앱 설정에서 허용해 주세요.",details:nil)); return }
            do { try self.startInput(); result(nil) } catch { self.stop(); result(FlutterError(code:"microphone",message:error.localizedDescription,details:nil)) }
          }
        }
      case "openSettings": if let url = URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }; result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    } catch { stop(); result(FlutterError(code:"audio",message:error.localizedDescription,details:nil)) }
  }
  private func stop() {
    generation += 1; micPending = false
    if micActive { engine?.inputNode.removeTap(onBus:0) }
    engine?.stop(); engine = nil; source = nil; micActive = false
    try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
  }
  private func click(_ frequency: Double, _ bright: Bool) -> [Float] {
    (0..<960).map { i in
      let t = Double(i)/48000
      return Float((sin(2 * .pi * frequency * t) + (bright ? 0.25 * sin(2 * .pi * frequency * 2.7 * t) : 0)) * exp(-t * (bright ? 380 : 240)))
    }
  }
  private func startOutput() throws {
    stop()
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback,mode:.default,options:[])
    try session.setPreferredSampleRate(48000); try session.setPreferredIOBufferDuration(0.0053); try session.setActive(true)
    guard session.sampleRate > 0, session.outputNumberOfChannels > 0 else {
      throw NSError(domain:"TempoTune",code:2,userInfo:[NSLocalizedDescriptionKey:"사용 가능한 오디오 출력이 없어요. 기기의 오디오 연결을 확인해 주세요."])
    }
    let e = AVAudioEngine()
    let format = AVAudioFormat(standardFormatWithSampleRate:48000,channels:1)!
    let sounds = ["wood":[click(1500,true),click(950,true)],"sine":[click(1000,false),click(650,false)],"bright":[click(2400,true),click(1600,true)]]
    var position = 960, gain = 0.0
    var clock = FrameClock()
    var active = sounds["wood"]![0]
    let currentGeneration = generation
    let node = AVAudioSourceNode(format:format) { [weak self] _, _, frames, bufferList -> OSStatus in
      guard let self = self else { return noErr }
      self.lock.lock()
      let tempo = self.bpm, meter = self.beats, denominator = self.denominator, volume = self.volume
      let sound = self.sound, muted = self.muted, accent = self.accent
      self.lock.unlock()
      let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
      for i in 0..<Int(frames) {
        if let beat = clock.next(bpm: tempo, beats: meter, denominator: denominator) {
          let strong = accent && FrameClock.strong(beat, denominator, meter)
          active = sounds[sound]![strong ? 0 : 1]; position = 0
          gain = muted.contains(beat) ? 0 : volume * (strong ? 1 : 0.65)
          let eventBeat = beat
          DispatchQueue.main.async { [weak self] in
            guard let self = self, self.generation == currentGeneration else { return }
            self.sink?(["type":"beat","beat":eventBeat])
          }
        }
        let sample: Float = position < active.count ? active[position] * Float(gain) : 0
        position += 1
        for buffer in buffers { buffer.mData?.assumingMemoryBound(to:Float.self)[i] = sample }
      }
      return noErr
    }
    e.attach(node); e.connect(node,to:e.mainMixerNode,format:format)
    engine = e; source = node
    try e.start()
  }
  private func startInput() throws {
    stop()
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record,mode:.measurement,options:[])
    try session.setPreferredSampleRate(48000); try session.setActive(true)
    let e = AVAudioEngine(), input = e.inputNode
    let format = input.outputFormat(forBus:0)
    guard format.sampleRate > 0 else { throw NSError(domain:"TempoTune",code:1,userInfo:[NSLocalizedDescriptionKey:"마이크를 사용할 수 없어요"]) }
    let currentGeneration = generation
    analysis.sync { frame.removeAll(keepingCapacity:true); phase = 0; sum = 0; count = 0 }
    micActive = true
    input.installTap(onBus:0,bufferSize:2048,format:format) { [weak self] buffer,_ in
      guard let self = self, let values = buffer.floatChannelData?[0] else { return }
      let copied = Array(UnsafeBufferPointer(start:values,count:Int(buffer.frameLength)))
      self.analysis.async { [weak self] in
        guard let self = self else { return }
        for value in copied {
          self.sum += Double(value); self.count += 1; self.phase += 12000
          if self.phase >= format.sampleRate {
            self.frame.append(self.sum/Double(self.count)); self.sum = 0; self.count = 0; self.phase -= format.sampleRate
            if self.frame.count == 4096 {
              let samples = self.frame; self.frame.removeAll(keepingCapacity:true)
              DispatchQueue.main.async { [weak self] in
                guard let self = self, self.generation == currentGeneration, self.micActive else { return }
                self.sink?(["type":"pcm","samples":samples])
              }
            }
          }
        }
      }
    }
    engine = e; try e.start()
  }
}

// FRAME_CLOCK_START
// Shared with the executable native scheduling test (tool/test_native_clock.py).
struct FrameClock {
  private var remaining = 0.0
  private var previousInterval = 0.0
  private var beat = 0
  static func strong(_ beat: Int, _ denominator: Int, _ beats: Int = 4) -> Bool {
    beat == 0 || (denominator == 8 && (beats == 7 ? (beat == 2 || beat == 4) : beat % 3 == 0))
  }
  mutating func next(bpm: Double, beats: Int, denominator: Int) -> Int? {
    let interval = 48000 * 60 / bpm * 4 / Double(denominator)
    if previousInterval > 0 && interval != previousInterval {
      remaining *= interval / previousInterval
    }
    previousInterval = interval
    var event: Int? = nil
    if remaining <= 0 {
      beat %= beats; event = beat; beat = (beat+1) % beats
      remaining += interval
    }
    remaining -= 1
    return event
  }
}
// FRAME_CLOCK_END
