function p = i1CalibrateAndMeasure(p)
%   [] = i1CalibrateAndMeasure(p)

% check if i1 is connected:
p.rig.i1Connected = I1('IsConnected');

% tell user to put device in calibration cradle then wait for them to press
% a key before initiating calibration:
disp('Place photomer in calibration cradle then press any keyboard key.');
pause;
I1('Calibrate');

% tell user calibration is complete:
disp('Calibration complete.')

% tell user to place photomer on screen for measurement then wait for key
% press to continue to measurement:
disp('Place photomer on screen for measurement.');
pause;

% preallocate space (3 color coords X nIntensities X 3 guns):
nIntensities = 256;
colorData = zeros(3, nIntensities, 3);
colorStrings = {'red', 'green', 'blue'};

% loop over guns to measure lum / chrom at each intensity level:
for i = 1:3
    
    % tell user what's going on:
    disp(['measuring ' colorStrings{i} ' gun.']);

    % make waitbar:
    hWait = waitbar(0, 'Looping over intensities...');

    % loop over intensities
    for j = 1:nIntensities

        % make color vector with all zeros
        tempColor = [0 0 0];

        % make one gun full intensity other guns zero
        tempColor(i) = j-1;

        % fill screen with color
        Screen('FillRect', p.draw.window, tempColor);
        Screen('Flip', p.draw.window);

        % trigger measurement
        I1('TriggerMeasurement');

        % retrieve measurement:
        colorData(:, j, i) = I1('GetTriStimulus');

        % update waitbat
        waitbar(j/nIntensities, hWait);
    end

    % close waitbar:
    close(hWait);
end

% where to save output:
saveString = ...
    fullfile(p.init.outputFolder, [p.init.sessionId '_x1Data.mat']);

% tell user what's going on:
disp(['Saving data to: ' saveString]);

% save measurement output 'x1Data':
save(saveString, 'colorData');
end