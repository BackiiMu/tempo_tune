package com.example.tempo_tune

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.abs

class FrameClockTest {
 @Test fun thirtyMinuteDriftAndBeatOrder() {
  for(bpm in listOf(60.0,120.0,180.0,137.0)) {
   val clock=FrameClock();var events=0;var maxDrift=0.0
   val interval=48000*60/bpm
   for(frame in 0 until 48000*60*30) {
    val beat=clock.next(bpm,4,4) ?: continue
    assertEquals(events%4,beat)
    val drift=abs(frame-events*interval);maxDrift=maxOf(maxDrift,drift)
    assertTrue("$bpm BPM drift $drift",drift<1.001)
    events++
   }
   println("$bpm BPM: $events events / 30 simulated minutes, max drift $maxDrift frames")
  }
 }
 @Test fun compoundGroupsAndTempoUpdate() {
  val clock=FrameClock();val events=mutableListOf<Int>();val accents=mutableListOf<Int>()
  for(frame in 0 until 144000) {
   val beat=clock.next(120.0,6,8) ?: continue
   events.add(frame);if(FrameClock.strong(beat,8))accents.add(beat)
  }
  assertEquals(listOf(0,12000,24000,36000),events.take(4))
  assertEquals(listOf(0,3,0,3),accents.take(4))
  assertEquals(listOf(0,2,4),(0..6).filter{FrameClock.strong(it,8,7)})
  val change=FrameClock();repeat(12000){change.next(120.0,4,4)}
  var wait=0;while(change.next(180.0,4,4)==null)wait++
  assertTrue(abs(wait-8000)<=1)
 }
}
