function p = playTone(p, whichTone)

% playTone(p, whichTone)
%
% Play a standard PLDAPS tone (low/high/noise) or one of the explicit SRS
% feedback tones (failure/lowReward/highReward), and strobe its category.

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
        bufferAddress = p.audio.wrongBuffAdd;
    case 'high'
        p.init.strb.strobeNow(p.init.codes.highTone);
        bufferAddress = p.audio.rightBuffAdd;
    case 'noise'
        p.init.strb.strobeNow(p.init.codes.noiseTone);
        bufferAddress = p.audio.noiseBuffAdd;
    case 'failure'
        p.init.strb.strobeNow(p.init.codes.lowTone);
        bufferAddress = requireBuffer(p.audio, ...
            'failureBuffAdd', 'failure');
    case 'lowReward'
        p.init.strb.strobeNow(p.init.codes.noiseTone);
        bufferAddress = requireBuffer(p.audio, ...
            'lowRewardBuffAdd', 'lowReward');
    case 'highReward'
        p.init.strb.strobeNow(p.init.codes.highTone);
        bufferAddress = requireBuffer(p.audio, ...
            'highRewardBuffAdd', 'highReward');
    otherwise
        error('SRS:UnknownTone', 'Unknown feedback tone: %s', whichTone);
end
Datapixx('SetAudioSchedule', 0, p.audio.freq, p.audio.nTF, ...
    p.audio.lrMode, bufferAddress, p.audio.nTF);
Datapixx('RegWrRd');

% play tone and update registers on DATAPixx
Datapixx('StartAudioSchedule');
Datapixx('RegWrRd');

% note the time the tone was played
p.trData.timing.tone = Datapixx('GetTime') - p.trData.timing.trialStartPTB;
p.trData.feedbackTone = string(whichTone);

end

function bufferAddress = requireBuffer(audio, fieldName, toneName)
if ~isfield(audio, fieldName)
    error('SRS:FeedbackAudioNotInitialized', ...
        ['Tone %s was requested, but %s is missing. Enable the ', ...
         'three-tone initializer in srsSmooth_init.'], toneName, fieldName);
end
bufferAddress = audio.(fieldName);
end
