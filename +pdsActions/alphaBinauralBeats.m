function p = alphaBinauralBeats(p)
Datapixx('SetAudioSchedule', 0, p.audio.freq, 0, 3, ...
    p.audio.alphaBuffAdd, p.audio.nBufferFrames);
Datapixx('StartAudioSchedule');
Datapixx('RegWrRd');
end