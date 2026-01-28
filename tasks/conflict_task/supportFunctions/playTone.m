function p = playTone(p, whichTone)

% playTone(p, whichTone)
%
% play a tone; either low, high or noise (depending on "whichTone"), and
% strobe the appropriate value.

% set the appropriate schedule depending on which tone is desired, and
% strobe the appropriate value.
switch whichTone
    case 'low'
        p.init.strb.strobeNow(p.init.codes.lowTone);
        Datapixx('SetAudioSchedule', 0, p.audio.freq, p.audio.nTF, p.audio.lrMode, ...
            p.audio.wrongBuffAdd, p.audio.nTF);
    case 'high'
        p.init.strb.strobeNow(p.init.codes.highTone);
        Datapixx('SetAudioSchedule', 0, p.audio.freq, p.audio.nTF, p.audio.lrMode, ...
            p.audio.rightBuffAdd, p.audio.nTF);
    case 'noise'
        p.init.strb.strobeNow(p.init.codes.noiseTone);
        Datapixx('SetAudioSchedule', 0, p.audio.freq, p.audio.nTF, p.audio.lrMode, ...
            p.audio.noiseBuffAdd, p.audio.nTF);
end

% play tone and update registers on DATAPixx
Datapixx('StartAudioSchedule');
Datapixx('RegWrRd');

% note the time the tone was played
p.trData.timing.tone = GetSecs - p.trData.timing.trialStartPTB;

end
