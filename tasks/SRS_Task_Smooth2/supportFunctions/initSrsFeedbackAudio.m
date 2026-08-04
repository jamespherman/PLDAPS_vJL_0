function p = initSrsFeedbackAudio(p)
%INITSRSFEEDBACKAUDIO Load three deterministic SRS outcome tones.
%
% The standard PLDAPS audio initializer creates two sine tones and noise.
% MoreTraining instead uses three sine tones so reward magnitude and failure
% have unambiguous feedback. Existing DATAPixx buffer addresses are reused;
% this changes audio only for settings that enable useThreeOutcomeTones.

requiredFields = {'freq', 'nTF', 'wrongBuffAdd', ...
    'rightBuffAdd', 'noiseBuffAdd'};
for iField = 1:numel(requiredFields)
    if ~isfield(p.audio, requiredFields{iField})
        error('SRS:AudioNotInitialized', ...
            'pds.initAudio must run before initSrsFeedbackAudio.');
    end
end

failureHz = getAudioFrequency(p.audio, 'feedbackFailureFreqHz', 150);
lowRewardHz = getAudioFrequency(p.audio, 'feedbackLowRewardFreqHz', 450);
highRewardHz = getAudioFrequency(p.audio, 'feedbackHighRewardFreqHz', 900);

if numel(unique([failureHz, lowRewardHz, highRewardHz])) ~= 3
    error('SRS:FeedbackToneFrequenciesNotUnique', ...
        'Failure, low-reward, and high-reward tones must use distinct frequencies.');
end

p.audio.failureTone = makeWindowedTone( ...
    failureHz, p.audio.freq, p.audio.nTF);
p.audio.lowRewardTone = makeWindowedTone( ...
    lowRewardHz, p.audio.freq, p.audio.nTF);
p.audio.highRewardTone = makeWindowedTone( ...
    highRewardHz, p.audio.freq, p.audio.nTF);

% Reuse the three standard audio buffers, but give them explicit names.
p.audio.failureBuffAdd = p.audio.wrongBuffAdd;
p.audio.lowRewardBuffAdd = p.audio.rightBuffAdd;
p.audio.highRewardBuffAdd = p.audio.noiseBuffAdd;

if isfield(p.init, 'useDataPixxBool') && p.init.useDataPixxBool
    Datapixx('WriteAudioBuffer', ...
        p.audio.failureTone, p.audio.failureBuffAdd);
    Datapixx('WriteAudioBuffer', ...
        p.audio.lowRewardTone, p.audio.lowRewardBuffAdd);
    Datapixx('WriteAudioBuffer', ...
        p.audio.highRewardTone, p.audio.highRewardBuffAdd);
    Datapixx('RegWrRd');
end

p.audio.feedbackFailureFreqHz = failureHz;
p.audio.feedbackLowRewardFreqHz = lowRewardHz;
p.audio.feedbackHighRewardFreqHz = highRewardHz;

fprintf(['SRS feedback tones loaded: failure=%g Hz, low reward=%g Hz, ', ...
    'high reward=%g Hz, duration=%.0f ms.\n'], ...
    failureHz, lowRewardHz, highRewardHz, ...
    1000 * p.audio.nTF / p.audio.freq);

end

function frequencyHz = getAudioFrequency(audio, fieldName, defaultValue)
frequencyHz = defaultValue;
if isfield(audio, fieldName)
    candidate = double(audio.(fieldName));
    if isscalar(candidate) && isfinite(candidate) && candidate > 0
        frequencyHz = candidate;
    else
        error('SRS:InvalidFeedbackToneFrequency', ...
            '%s must be a finite positive scalar.', fieldName);
    end
end
end

function tone = makeWindowedTone(frequencyHz, sampleRateHz, nFrames)
timeSec = (0:(nFrames - 1)) / sampleRateHz;
tone = sin(2 * pi * frequencyHz * timeSec);

% Ten-millisecond cosine ramps prevent clicks without changing duration.
nRamp = min(round(0.010 * sampleRateHz), floor(nFrames / 2));
if nRamp > 0
    ramp = sin(linspace(0, pi / 2, nRamp)).^2;
    amplitudeWindow = ones(1, nFrames);
    amplitudeWindow(1:nRamp) = ramp;
    amplitudeWindow((end - nRamp + 1):end) = fliplr(ramp);
    tone = tone .* amplitudeWindow;
end

peak = max(abs(tone));
if peak > 0
    tone = tone / peak;
end
end
