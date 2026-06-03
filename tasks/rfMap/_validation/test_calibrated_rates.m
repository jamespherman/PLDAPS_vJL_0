% test_calibrated_rates.m  Quick sanity check of calibrated sim rates.
% Runs a mock kernel bank build and spike generation for a few channels
% to verify the rate calibration produces ~5-10 spk/ch/trial.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));

% Mock the minimal p struct needed by simInitKernelBank
p = struct();
p.trVarsInit.nChannels       = 64;
p.trVarsInit.nSTALags        = 8;
p.trVarsInit.checkSizeDeg    = 2.0;
p.trVarsInit.noiseFrameHold  = 12;
p.trVarsInit.simBaseSeed     = 42;
p.trVarsInit.dklAxes         = [1 2 3];
p.trVarsInit.dklContrasts    = 0.45;
p.rig.frameDuration          = 1/120;
p.init.stimType              = 'denseChromatic';
p.init.noiseGridSize         = [22 34];

p = simInitKernelBank(p);
bank = p.init.simKernelBank;

fprintf('\n=== RATE CALIBRATION CHECK ===\n');
fprintf('RF channels: %d | Noise channels: %d\n', ...
    bank.nSimulated, bank.nNoiseChannels);

% Print per-channel rates
fprintf('\nRF channel rates:\n');
for ch = 1:bank.nSimulated
    k = bank.kernels{ch};
    fprintf('  ch%02d: base=%.1f peak=%.1f spk/s\n', ...
        ch, k.baseRate, k.peakRate);
end

fprintf('\nNoise channel rates (first 8):\n');
for ch = bank.nSimulated+1 : min(bank.nSimulated+8, bank.nChannels)
    k = bank.kernels{ch};
    fprintf('  ch%02d: base=%.1f spk/s (noise)\n', ch, k.baseRate);
end

% Estimate expected spikes per trial
trialDurS = 15 * (12/120);  % 15 frames at noiseFrameHold=12
fprintf('\nExpected spikes per 1.5s trial:\n');
rfRates = zeros(bank.nSimulated, 1);
for ch = 1:bank.nSimulated
    k = bank.kernels{ch};
    % Rough: base + peak*sigmoid(0) = base + peak*0.5 at zero drive
    avgRate = k.baseRate + k.peakRate * 0.5;
    rfRates(ch) = avgRate;
    expected = avgRate * trialDurS;
    if ch <= 8
        fprintf('  ch%02d: ~%.1f Hz -> ~%.1f spk/trial\n', ch, avgRate, expected);
    end
end
fprintf('  RF channels: median %.1f Hz -> %.1f spk/trial\n', ...
    median(rfRates), median(rfRates) * trialDurS);

noiseRates = zeros(bank.nNoiseChannels, 1);
for ch = bank.nSimulated+1 : bank.nChannels
    k = bank.kernels{ch};
    noiseRates(ch - bank.nSimulated) = k.baseRate;
end
fprintf('  Noise channels: median %.1f Hz -> %.1f spk/trial\n', ...
    median(noiseRates), median(noiseRates) * trialDurS);

% Compare to real data target
fprintf('\nReal LGN target: ~5-10 spk/ch/trial at 1.5s = ~3-7 Hz\n');
fprintf('Calibrated RF sim: median %.1f Hz (range %.1f-%.1f)\n', ...
    median(rfRates), min(rfRates), max(rfRates));
fprintf('Calibrated noise sim: median %.1f Hz (range %.1f-%.1f)\n', ...
    median(noiseRates), min(noiseRates), max(noiseRates));

exit;
