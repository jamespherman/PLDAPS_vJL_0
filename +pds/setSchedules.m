function p = setSchedules(p)
%
% p = setSchedules(p)
%
% Initialize VIEWPixx/DATAPixx hardware schedules:
% (1) Set up continuous sampling of analog inputs (eye position, joystick) at
%     specified rate with circular buffer.
% (2) If audio playback from PC is enabled, configure audio input capture and
%     playback with specified delay.

if p.rig.dp.useDataPixxBool
   % Set ADC schedule: continuously sample analog inputs into a circular 
   % buffer for the duration of the experiment. Buffer must be large enough
   % to prevent overwriting before data is read out on each trial.
   Datapixx('SetAdcSchedule', ...
       0, ...                                   % onset delay (s)
       p.rig.dp.adcRate, ...                   % sampling rate (Hz)
       p.rig.dp.adcRate * p.rig.dp.maxDurADC, ... % buffer size (samples)
       [0 1 2 3], ...                          % channels to sample
       p.rig.dp.adcBuffAddr, ...               % buffer start address
       p.rig.dp.adcRate * p.rig.dp.maxDurADC); % buffer size (redundant)
   Datapixx('RegWrRd');
   
   % Check if PC audio playback is enabled. This requires capturing audio
   % input from the PC and routing it to the VIEWPixx audio output with 
   % minimal delay while avoiding audio feedback.
   if isfield(p.audio, 'pcPlayback') && p.audio.pcPlayback
       
       % Calculate minimum input-to-output delay that ensures samples are
       % written to DRAM before attempting playback.
       feedbackDelay = 2 / p.audio.freq;
       
       % Allocate 20MB buffer (~100s at 48kHz) for audio capture/playback.
       micBuffSize = 20e6;
       
       % Configure audio input: maximum gain, disable output-to-input
       % loopback to prevent feedback.
       Datapixx('SetMicrophoneSource', 2, 50);
       Datapixx('DisableAudioLoopback');
       
       % Set up continuous mono audio capture starting immediately.
       Datapixx('SetMicrophoneSchedule', ...
           0, ...                  % onset delay (s)
           p.audio.freq, ...       % sampling rate (Hz)
           0, ...                  % max frames (0 = unlimited)
           3, ...                  % mode (3 = mono)
           p.audio.nextBuffAdd, ... % buffer start address
           micBuffSize);           % buffer size (bytes)
       
       % Configure audio output to play captured samples with minimum delay.
       Datapixx('SetAudioSchedule', ...
           feedbackDelay, ...      % onset delay (s)
           p.audio.freq, ...       % sampling rate (Hz)
           0, ...                  % max frames (0 = unlimited)
           3, ...                  % mode (3 = mono)
           p.audio.nextBuffAdd, ... % buffer start address
           micBuffSize);           % buffer size (bytes)
       
       % Update registers to initiate audio I/O configuration
       Datapixx('RegWrRd');
   end
end