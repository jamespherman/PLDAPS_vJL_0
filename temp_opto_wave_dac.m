% Connect to DATAPixx hardware
Datapixx('Open');

% Define DAC sampling rate in Hz
dacRate = 1000;

% Duration of zero-voltage padding at start and end of signal (seconds)
dacPadDur = 0.01;

% Base address for DAC buffer
dacBuffAddr = 0;

% DAC output channel for LED control
dacChannelOut = 1;

% Total desired duration of the pulse train in seconds
trainDur = 0.5;

% Duration of each individual pulse in seconds
pulseDur = 0.5;

% Voltage amplitude of pulses in volts
pulseAmp = 4;

% Time from start of one pulse to start of next pulse in seconds
ipi = 0.0;

% Handle constant voltage case (ipi = 0) differently from pulsed case
if ipi == 0
    % For constant voltage, treat as one long pulse
    nPulses = 1;
    actualTrainDur = trainDur;
    dacWaveOutDur = actualTrainDur + 2*dacPadDur;
else
    % Calculate number of complete pulses that will fit in the train duration
    cycleLength = pulseDur + ipi;
    nPulses = floor(trainDur / cycleLength);
    % Calculate actual train duration to fit complete pulses
    actualTrainDur = nPulses * cycleLength;
    dacWaveOutDur = actualTrainDur + 2*dacPadDur;
end

% Convert timing parameters to sample counts
samplesPerPulse = round(pulseDur * dacRate);
samplesPeripi = round(ipi * dacRate);
samplesPadding = round(dacPadDur * dacRate);

% Initialize waveform array with zeros
dacWaveOut = zeros(1, round(dacWaveOutDur * dacRate));

% Generate waveform based on mode
if ipi == 0
    % Constant voltage case - one long pulse
    startIdx = samplesPadding + 1;
    endIdx = length(dacWaveOut) - samplesPadding;
    dacWaveOut(startIdx:endIdx) = pulseAmp;
else
    % Pulsed case - generate individual pulses
    for i = 1:nPulses
        startIdx = samplesPadding + (i-1)*(samplesPerPulse + samplesPeripi) + 1;
        endIdx = startIdx + samplesPerPulse - 1;
        dacWaveOut(startIdx:endIdx) = pulseAmp;
    end
end

% Display information
fprintf('Requested duration: %.3f seconds\n', trainDur);
fprintf('Actual duration: %.3f seconds\n', actualTrainDur);
if ipi == 0
    fprintf('Mode: Constant voltage\n');
else
    fprintf('Mode: Pulsed\n');
    fprintf('Number of pulses: %d\n', nPulses);
end

% Write waveform to DAC buffer and configure schedule
Datapixx('RegWrRd');
Datapixx('WriteDacBuffer', ...
    dacWaveOut, ...
    dacBuffAddr, ...
    dacChannelOut);
Datapixx('SetDacSchedule', ...
    0, ...
    dacRate, ...
    length(dacWaveOut), ...
    1, ...
    dacBuffAddr, ...
    length(dacWaveOut));
Datapixx('RegWrRd');

% Start DAC schedule
Datapixx('StartDacSchedule');
Datapixx('RegWrRd');

% Wait for schedule completion
dacStatus = Datapixx('GetDacStatus');
while dacStatus.scheduleRunning
    WaitSecs(0.05);
    Datapixx('RegWrRd');
    dacStatus = Datapixx('GetDacStatus');
end

% Reset DAC voltages to zero
Datapixx('SetDacVoltages', [1 0]);
Datapixx('RegWrRd');

% Close DATAPixx connection
Datapixx('Close');