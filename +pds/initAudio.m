function p                      = initAudio(p)
%% Audio Stuff
% Variables.
p.audio.freq          = 48000;                  % Sampling rate.
p.audio.rightFreq     = 300;                    % A low-frequency tone to signal "WRONG"
p.audio.wrongFreq     = 150;                    % A high-frequency tone to signal "RIGHT"
p.audio.nTF           = round(p.audio.freq/10); % The tone-duration.
p.audio.lrMode        = 0;                      % Mono sound on both channels.
p.audio.beatsF1       = (1/0.0125);             % Define frequency 1 for "alpha binaural beats"
p.audio.beatsF2       = (1/0.015);              % Define frequency 2 for "alpha binaural beats"
p.audio.beatsDur      = 0.015*5;                % Define duration of "alpha binaural beats" audio.

% ... and for a frequency sweep tone
p.audio.sweepDur      = 0.5;                    % Duration of the sweep (seconds).
p.audio.sweepLow      = 300;                    % Low frequency of the sweep (Hz).
p.audio.sweepHigh     = 450;                    % High frequency of the sweep (Hz).

% time vector for "alpha binaural beats" audio
tempTime              = 0:(1/p.audio.freq):p.audio.beatsDur;
tempTime              = tempTime(1:end-1);

% make an audio clip of "alpha binaural beats"
p.audio.nBufferFrames = length(tempTime);
beatsChannel1         = sin(2*pi*p.audio.beatsF1*tempTime);
beatsChannel2         = sin(2*pi*p.audio.beatsF2*tempTime);
p.audio.alphaBeats    = [beatsChannel1; beatsChannel2];

% Create a frequency sweep
% Create a time vector for the sweep
sweepTime = 0:(1/p.audio.freq):p.audio.sweepDur;
sweepTime = sweepTime(1:end-1);

% Create the frequency modulation
nSweepFrames = length(sweepTime);
halfSweep = round(nSweepFrames/2);
freqMod = [linspace(p.audio.sweepLow, p.audio.sweepHigh, halfSweep), linspace(p.audio.sweepHigh, p.audio.sweepLow, nSweepFrames-halfSweep)];

% Generate the sweep tone
p.audio.sweepTone = sin(2*pi*cumsum(freqMod)/p.audio.freq);

% Make a new window for the sweep tone
riseFallPropSweep = 1/8; % Shorter rise/fall for the longer tone
plateauPropSweep = 1 - 2*riseFallPropSweep;
muSweep = round(riseFallPropSweep*nSweepFrames);
sigmaSweep = round(nSweepFrames/24);
sweepWindow = [normpdf(1:muSweep,muSweep,sigmaSweep),...
    ones(1,round(plateauPropSweep*nSweepFrames))*normpdf(muSweep,muSweep,sigmaSweep),...
    fliplr(normpdf(1:muSweep,muSweep,sigmaSweep))];
sweepWindow = sweepWindow - min(sweepWindow);
sweepWindow = sweepWindow/max(sweepWindow);

% Apply window and normalize
p.audio.sweepTone = sweepWindow.*p.audio.sweepTone;
p.audio.sweepTone = p.audio.sweepTone/max(abs(p.audio.sweepTone));


% Make a plateau-ed window with gaussian rise and fall at the beginning and
% end. Start by making the gaussian rise at the beginning. Use somewhat
% arbitrary values of MU and SIGMA to position the rise/fall in a place that
% you like.
riseFallProp                    = 1/4;                              % proportion of sound for rise/fall
plateauProp                     = 1-2*riseFallProp;                 % proportion of sound for plateau
mu1                             = round(riseFallProp*p.audio.nTF);        % Gaussian mean expressed in samples
sigma1                          = round(p.audio.nTF/12);                  % Gaussian SD in samples, effectively the rate of rise/fall.

tempWindow                      = [normpdf(1:mu1,mu1,sigma1),...                                % RISE
    ones(1,round(plateauProp*p.audio.nTF))*normpdf(mu1,mu1,sigma1),...    % PLATEAU (scaled to meet the rise/fall)
    fliplr(normpdf(1:mu1,mu1,sigma1))];                             % FALL

% Additively scale the window to ensure that it starts and ends at zero.
tempWindow                      = tempWindow - min(tempWindow);

% Multiplicatively scale the window to put the plateau at one.
tempWindow                      = tempWindow/max(tempWindow);

% Make the two sounds, one at 150hz ("righttone"), one at 300hz ("wrongtone").
p.audio.wrongTone     = tempWindow.*sin((1:p.audio.nTF)*2*pi*p.audio.wrongFreq/p.audio.freq);
p.audio.rightTone     = tempWindow.*sin((1:p.audio.nTF)*2*pi*p.audio.rightFreq/p.audio.freq);
p.audio.noiseTone     = tempWindow.*((rand(1,p.audio.nTF)-0.5)*2);

% Normalize the windowed sounds (keep them between -1 and 1. Scale down the
% noise tone a bit because it sounds too loud relative to "rightTone".
p.audio.wrongTone     = p.audio.wrongTone/max(abs(p.audio.wrongTone));
p.audio.rightTone     = p.audio.rightTone/max(abs(p.audio.rightTone));
p.audio.noiseTone     = 0.6*(p.audio.noiseTone/max(abs(p.audio.noiseTone)));

% check to make sure there's a "lineOutLevel" subfield of "p.audio", if
% there isn't, define it. We use this value to set the output volume level
% of the datapixx, and prior to "now" (2022 - 01 - 26) we didn't have a
% variable to define this.
if ~isfield(p.audio, 'lineOutLevel')
    p.audio.lineOutLevel = 0.3;
end

% load tones into DATAPixx memory. First write "wrongTone", then
% "rightTone" then "noiseTone". Each write operation returns the memory
% address for the next available audio data so writing "wrongTone" returns
% "rightBuffAdd", writing "rightTone" returns "noiseBuffAdd", writing
% "noiseTone" returns "alphaBuffAdd", and writing "alphaBufAdd" returns
% "nextBuffAdd"
if p.init.useDataPixxBool
Datapixx('InitAudio');
Datapixx('SetAudioVolume', p.audio.lineOutLevel);
p.audio.wrongBuffAdd  = 0; % Start-address of the first sound's buffer.
p.audio.rightBuffAdd = Datapixx('WriteAudioBuffer', p.audio.wrongTone, p.audio.wrongBuffAdd);
p.audio.noiseBuffAdd = Datapixx('WriteAudioBuffer', p.audio.rightTone, p.audio.rightBuffAdd);
p.audio.alphaBuffAdd = Datapixx('WriteAudioBuffer', p.audio.noiseTone, p.audio.noiseBuffAdd);
p.audio.sweepBuffAdd = Datapixx('WriteAudioBuffer', p.audio.alphaBeats, p.audio.alphaBuffAdd);
p.audio.nextBuffAdd  = Datapixx('WriteAudioBuffer', p.audio.sweepTone, p.audio.sweepBuffAdd);
Datapixx('RegWrRd');
end
end