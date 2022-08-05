function p = alphaBinauralBeats(p)
Datapixx('SetAudioSchedule', 0, p.audio.freq, 0, 3, ...
    p.audio.alphaBufAdd, p.audio.nBufferFrames);
Datapixx('StartAudioSchedule');
Datapixx('RegWrRd');
end