function p = setSchedules(p)

% c = setSchedules(p)
%
% Define ("set") scheduls for analog to digital converter (ADC) and digital
% to analog converter (DAC) on VIEWPixx / DATAPixx.

if p.init.useVPixx
% Set ADC schedule with a buffer of "maxDur" seconds sampling "adcRate"
% samples / second.
Datapixx('SetAdcSchedule', ...
    0, ...                          % start delay (s)
    p.rig.dp.adcRate, ...                  % samping rate
    p.rig.dp.adcRate * p.rig.dp.maxDurADC, ...      % memory buffer size in samples
    [0 1 2 3], ...                  % list of channels to sample from
    p.rig.dp.adcBuffAddr, ...              % memory buffer base address
    p.rig.dp.adcRate * p.rig.dp.maxDurADC ...      % number of buffer frames (redundant)
    );
Datapixx('RegWrRd');

% Build a square wave of the desired duration to output on the DAC for
% controlling the liquid reward solenoid open duration. Pad the +4v square
% wave with 10ms of zeros on either side to avoid unwanted weirdness with
% the DAC.
dacWaveOutDur   = p.trVars.rewardDurationMs / 1e3 + p.rig.dp.dacPadDur; % duration in seconds
dacWaveOut      = [zeros(1, p.rig.dp.dacRate * p.rig.dp.dacPadDur / 2) ...
    4 * ones(1,p.rig.dp.dacRate * p.trVars.rewardDurationMs / 1e3) ...
    zeros(1,p.rig.dp.dacRate * p.rig.dp.dacPadDur / 2)];

% Set DAC schedule (for reward system) for channel
Datapixx('RegWrRd');
Datapixx('WriteDacBuffer', ...
    dacWaveOut, p.rig.dp.dacBuffAddr, p.rig.dp.dacChannelOut);
Datapixx('SetDacSchedule', 0, p.rig.dp.dacRate, fix(dacWaveOutDur * p.rig.dp.dacRate), ...
    0, p.rig.dp.dacBuffAddr, fix(dacWaveOutDur * p.rig.dp.dacRate));
Datapixx('RegWrRd');

% Check to see if audio playback from Psychtoolbox PC is desired; if so,
% set schedule to record audio on viewpixx input and playback on viewpixx
% output. Because we're adding this to a core "pds" functions of PLDAPS, we
% need to check if the variable is defined in the current task AND if the
% variable is set to true:
if isfield(p.audio, 'pcPlayback') && p.audio.pcPlayback

    % We'll require a minimum delay of 2 audio samples to ensure that the
    % audio input schedule can write its datum to DRAM before the audio
    % output schedule tries to read that location.
    feedbackDelay = 2 / p.audio.freq;
    
    % size of buffer to dedicate to microphone recording / playback:
    micBuffSize = 20e6;
    
    % tell datapixx to record from the audio input at maximum gain, and to
    % disable audio loopback (in which whatever is on the viewpixx output
    % is looped back to the input).
    Datapixx('SetMicrophoneSource', 2, 50);
    Datapixx('DisableAudioLoopback');
    
    % We'll record into address "p.audio.nextBuffAdd" which is the first
    % free audio buffer address after various tones have been loaded for
    % playback, with a 20 megabyte buffer for up to 100 seconds of
    % feedbackDelay at 48kSPS.
    Datapixx('SetMicrophoneSchedule', ...
        0, ...                      % schedule onset delay
        p.audio.freq, ...           % sample rate
        0, ...                      % maximum frames (0 = Inf)
        3, ...                      % stereo mode (3 == mono)
        p.audio.nextBuffAdd, ...    % where in memory to start buffering
        micBuffSize ...             % size of audio buffer allocated
        );
    
    % We'll playback from the same buffer ("p.audio.nextBuffAdd"), but with
    % a schedule onset delay (of 2 samples as defined above).
    Datapixx('SetAudioSchedule', feedbackDelay, p.audio.freq, 0, 3, ...
        p.audio.nextBuffAdd, micBuffSize);
    
    % sprinkle on the magic datapixx fairy dust:
    Datapixx('RegWrRd');
end

end