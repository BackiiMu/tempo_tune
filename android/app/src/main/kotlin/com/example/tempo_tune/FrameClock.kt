package com.example.tempo_tune

// Fractional frames preserve phase across buffer boundaries and tempo changes.
class FrameClock {
    private var remaining=0.0
    private var previousInterval=0.0
    private var beat=0
    fun next(bpm:Double,beats:Int,denominator:Int):Int? {
        val interval=48000*60.0/bpm*4.0/denominator
        if(previousInterval>0&&interval!=previousInterval)remaining*=interval/previousInterval
        previousInterval=interval
        var event:Int?=null
        if(remaining<=0){beat%=beats;event=beat;beat=(beat+1)%beats;remaining+=interval}
        remaining-=1
        return event
    }
    companion object { fun strong(beat:Int,denominator:Int,beats:Int=4)=beat==0||(denominator==8&&(if(beats==7)beat==2||beat==4 else beat%3==0)) }
}
