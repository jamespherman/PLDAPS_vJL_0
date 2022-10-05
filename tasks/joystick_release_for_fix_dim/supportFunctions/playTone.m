function p = playTone(p, whichTone)

% playTone(p, whichTone)
%
% play a tone; either low, high or noise (depending on "whichTone"), and
% strobe the appropriate value.

% if microphone / audio schedules are running, stop them:
Datapixx('RegWrRd');
micStatus = Datapixx('GetMicrophoneStatus');
audStatus = Datapixx('GetAudioStatus');
if micStatus.scheduleRunning
    Datapixx('StopMicrophoneSchedule');
end
if audStatus.scheduleRunning
    Datapixx('StopAudioSchedule');
end
Datapixx('RegWrRd');

% set the appropriate schedule depending on which tone is desired, and
% strobe the appropriate value.
switch whichTone
    case 'low'
        p.init.strb.strobeNow(p.init.codes.lowTone);
        Datapixx('SetAudioSchedule', 0, p.audio.freq, p.audio.nTF, ...
            p.audio.lrMode,  p.audio.wrongBuffAdd, p.audio.nTF);
    case 'high'
        p.init.strb.strobeNow(p.init.codes.highTone);
        Datapixx('SetAudioSchedule', 0, p.audio.freq, p.audio.nTF, ...
            p.audio.lrMode,  p.audio.rightBuffAdd, p.audio.nTF);
    case 'noise'
        p.init.strb.strobeNow(p.init.codes.noiseTone);
        Datapixx('SetAudioSchedule', 0, p.audio.freq, p.audio.nTF, ...
            p.audio.lrMode,  p.audio.noiseBuffAdd, p.audio.nTF);
end
Datapixx('RegWrRd');

% play tone and update registers on DATAPixx
Datapixx('StartAudioSchedule');
Datapixx('RegWrRd');

% note the time the tone was played
p.trData.timing.tone = Datapixx('GetTime') - p.trData.timing.trialStartPTB;

end