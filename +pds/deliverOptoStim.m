function p = deliverOptoStim(p)
%
% p = deliverOptoStim(p)
%
% (1) Define stimulation "waveform"
% (2) Write waveform to DAC buffer
% (3) Set DAC schedule
% (4) Strobe opto stim code
% (5) Start DAC schedule
% (6) Wait for DAC schedule to complete and set voltages to 0

% Handle constant voltage case (p.trVars.optoIpiSec = 0) differently from 
% pulsed case
if p.trVars.optoIpiSec == 0
    % For constant voltage, treat as one long pulse
    nPulses = 1;
    actualp.trVars.optoStimDurSec = p.trVars.optoStimDurSec;
    dacWaveOutDur = actualp.trVars.optoStimDurSec + 2*p.rig.dp.dacPadDur;
else
    % Calculate number of complete pulses that will fit in the train 
    % duration
    cycleLength = p.trVars.optoPulseDurSec + p.trVars.optoIpiSec;
    nPulses = floor(p.trVars.optoStimDurSec / cycleLength);
    % Calculate actual train duration to fit complete pulses
    actualp.trVars.optoStimDurSec = nPulses * cycleLength;
    dacWaveOutDur = actualp.trVars.optoStimDurSec + 2*p.rig.dp.dacPadDur;
end

% Convert timing parameters to sample counts
samplesPerPulse = round(p.trVars.optoPulseDurSec * p.rig.dp.dacRate);
samplesPerp.trVars.optoIpiSec = round(p.trVars.optoIpiSec * ...
    p.rig.dp.dacRate);
samplesPadding = round(p.rig.dp.dacPadDur * p.rig.dp.dacRate);

% Initialize waveform array with zeros
dacWaveOut = zeros(1, round(dacWaveOutDur * p.rig.dp.dacRate));

% Generate waveform based on mode
if p.trVars.optoIpiSec == 0
    % Constant voltage case - one long pulse
    startIdx = samplesPadding + 1;
    endIdx = length(dacWaveOut) - samplesPadding;
    dacWaveOut(startIdx:endIdx) = p.trVars.optoPulseAmpVolts;
else
    % Pulsed case - generate individual pulses
    for i = 1:nPulses
        startIdx = samplesPadding + (i-1)*(samplesPerPulse + ...
            samplesPerp.trVars.optoIpiSec) + 1;
        endIdx = startIdx + samplesPerPulse - 1;
        dacWaveOut(startIdx:endIdx) = p.trVars.optoPulseAmpVolts;
    end
end

% Write waveform to DAC buffer and configure schedule
Datapixx('RegWrRd');
Datapixx('WriteDacBuffer', ...
    dacWaveOut, ...
    p.rig.dp.dacBuffAddr, ...
    p.trVars.optoDacChan);
Datapixx('SetDacSchedule', ...
    0, ...
    p.rig.dp.dacRate, ...
    length(dacWaveOut), ...
    1, ...
    p.rig.dp.dacBuffAddr, ...
    length(dacWaveOut));
Datapixx('RegWrRd');

% Start DAC schedule
Datapixx('StartDacSchedule');
Datapixx('RegWrRd');