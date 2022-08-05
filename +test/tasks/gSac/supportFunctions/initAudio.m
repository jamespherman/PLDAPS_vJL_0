function p                      = initAudio(p)
%% Audio Stuff
% Variables.
p.audio.freq          = 48000;                % Sampling rate.
p.audio.rightFreq     = 300;                  % A low-frequency tone to signal "WRONG"
p.audio.wrongFreq     = 150;                  % A high-frequency tone to signal "RIGHT"
p.audio.nTF           = round(p.audio.freq/10);     % The tone-duration.
p.audio.lrMode        = 0;                    % Mono sound on both channels.
p.audio.wrongBuffAdd  = 0;                    % Start-address of the first sound's buffer.
p.audio.beatsF1       = (1/0.0125);
p.audio.beatsF2       = (1/0.015);
p.audio.beatsDur      = 0.015*5;

% time vector for alpha binaural "beats" audio
tempTime              = 0:(1/p.audio.freq):p.audio.beatsDur;
tempTime              = tempTime(1:end-1);

% make an audio clip of "alpha binaural beats"
p.audio.nBufferFrames = length(tempTime);
beatsChannel1         = sin(2*pi*p.audio.beatsF1*tempTime);
beatsChannel2         = sin(2*pi*p.audio.beatsF2*tempTime);
p.audio.alphaBeats    = [beatsChannel1; beatsChannel2];

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

% Normalize the windowed sounds (keep them between -1 and 1.
p.audio.wrongTone     = p.audio.wrongTone/max(abs(p.audio.wrongTone));
p.audio.rightTone     = p.audio.rightTone/max(abs(p.audio.rightTone));
p.audio.noiseTone     = p.audio.noiseTone/max(abs(p.audio.noiseTone));

% load tones into DATAPixx memory. First write "wrongTone", then
% "rightTone" then "noiseTone". Each write operation returns the memory
% address for the next available audio data so writing "wrongTone" returns
% "rightBuffAdd", writing "rightTone" returns "noiseBuffAdd", and writing
% "noiseTone" returns an as-yet-unused address.
Datapixx('InitAudio');
Datapixx('SetAudioVolume', 0.5);
p.audio.rightBuffAdd = Datapixx('WriteAudioBuffer', p.audio.wrongTone, p.audio.wrongBuffAdd);
p.audio.noiseBuffAdd = Datapixx('WriteAudioBuffer', p.audio.rightTone, p.audio.rightBuffAdd);
p.audio.alphaBufAdd  = Datapixx('WriteAudioBuffer', p.audio.noiseTone, p.audio.noiseBuffAdd);
Datapixx('WriteAudioBuffer', p.audio.alphaBeats, p.audio.alphaBufAdd);
Datapixx('RegWrRd');
end