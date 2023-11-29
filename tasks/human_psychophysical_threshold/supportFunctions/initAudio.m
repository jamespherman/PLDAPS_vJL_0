function p                      = initAudio(p)
%% Audio Stuff
% Variables.
p.audio.freq          = 48000;                  % Sampling rate.
p.audio.rightFreq     = 450;                    % A low-frequency tone to signal "WRONG"
p.audio.wrongFreq     = 250;                    % A high-frequency tone to signal "RIGHT"
p.audio.nTF           = round(p.audio.freq/4); % The tone-duration.

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
end