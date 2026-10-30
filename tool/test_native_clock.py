"""Compile and exercise the exact Swift frame clock used by AVAudioSourceNode.
This is deterministic scheduling simulation, not a physical audio measurement.
"""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'ios/Runner/AppDelegate.swift').read_text().split('// FRAME_CLOCK_START')[1].split('// FRAME_CLOCK_END')[0]
tests=r'''
import Foundation
func check(_ value: Bool, _ message: String) { if !value { fatalError(message) } }
for bpm in [60.0,120.0,180.0,137.0] {
  var clock=FrameClock()
  let duration=Int(48000*60*30) // 30 simulated minutes each
  let interval=48000*60/bpm
  var events=0
  var maximumDrift=0.0
  for frame in 0..<duration {
    if let beat=clock.next(bpm:bpm,beats:4,denominator:4) {
      check(beat==events%4,"4/4 beat order")
      let drift=abs(Double(frame)-Double(events)*interval)
      maximumDrift=max(maximumDrift,drift)
      check(drift<1.001,"sample drift")
      events+=1
    }
  }
  print("\(bpm) BPM: \(events) beats / 30 simulated minutes, max drift \(maximumDrift) frames")
}
var compound=FrameClock()
var positions=[Int]()
var strong=[Int]()
for frame in 0..<144000 {
 if let beat=compound.next(bpm:120,beats:6,denominator:8) {
  positions.append(frame)
  if FrameClock.strong(beat,8) { strong.append(beat) }
 }
}
check(positions.prefix(4).elementsEqual([0,12000,24000,36000]),"6/8 eighth intervals")
check(strong.prefix(4).elementsEqual([0,3,0,3]),"6/8 groups")
var change=FrameClock()
for _ in 0..<12000 { _=change.next(bpm:120,beats:4,denominator:4) }
var wait=0
while change.next(bpm:180,beats:4,denominator:4)==nil { wait+=1 }
check(abs(wait-8000)<=1,"tempo update phase")
check((0..<7).filter { FrameClock.strong($0,8,7) } == [0,2,4],"7/8 2+2+3 accents")
print("6/8, 7/8 accents and mid-beat tempo update passed")
'''
with tempfile.TemporaryDirectory(prefix='tempotune-clock-') as directory:
 p=Path(directory);(p/'main.swift').write_text(source+tests)
 subprocess.run(['swiftc','-O','-module-cache-path',str(p/'cache'),str(p/'main.swift'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
