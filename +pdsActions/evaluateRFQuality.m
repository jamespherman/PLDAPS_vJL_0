function p = evaluateRFQuality(p)
% pdsActions.evaluateRFQuality  Run computeChannelQuality and print results.
%
%   p = evaluateRFQuality(p)
%
%   Call from the GUI action menu after a denseAchromatic (or sparse) sim
%   session. Runs computeChannelQuality on the current STA accumulators
%   and prints per-channel pass/fail with RF center estimates.
%
%   In sim mode with a shared population file, also compares estimated RF
%   centers to ground truth and reports localization error.

if ~isfield(p.init, 'staAccum') || isempty(p.init.staAccum)
    fprintf('evaluateRFQuality: no STA accumulators on p.init. Run some trials first.\n');
    return;
end

if strcmp(p.init.stimType, 'checkerboard')
    fprintf('evaluateRFQuality: checkerboard mode does not produce spatial RFs.\n');
    fprintf('  Use the F1/F2 display for channel characterization.\n');
    return;
end

quality = computeChannelQuality(p);
nCh = p.trVarsInit.nChannels;

% Check if we have ground truth (sim mode with population).
hasGT = isfield(p.init, 'simKernelBank') && ...
    isfield(p.init.simKernelBank, 'templateCenters');

fprintf('\n=== RF QUALITY EVALUATION (%s, %d good trials) ===\n', ...
    p.init.stimType, p.status.iGoodTrial);

if hasGT
    fprintf('  ch | spatSNR | spkCnt | center (x,y) dva  | GT (x,y) dva       | err(dva) | pass\n');
    fprintf('  ---+---------+--------+--------------------+--------------------+----------+-----\n');
else
    fprintf('  ch | spatSNR | spkCnt | center (x,y) dva  | pass | failReasons\n');
    fprintf('  ---+---------+--------+--------------------+------+------------\n');
end

nPass = 0;
errVec = [];
for ch = 1:nCh
    q = quality(ch);
    if q.spikeCount < 10, continue; end

    centerStr = '      N/A       ';
    if ~any(isnan(q.rfCenterDeg))
        centerStr = sprintf('(%+6.2f, %+6.2f)', q.rfCenterDeg(1), q.rfCenterDeg(2));
    end

    if q.passGo, nPass = nPass + 1; end

    if hasGT
        k = p.init.simKernelBank.kernels{ch};
        gtStr = '      N/A       ';
        errStr = '   N/A  ';
        if ~isempty(k) && isfield(k, 'rfCenterFixFrame') && ~any(isnan(q.rfCenterDeg))
            gt = k.rfCenterFixFrame;
            gtStr = sprintf('(%+6.2f, %+6.2f)', gt(1), gt(2));
            err = sqrt(sum((q.rfCenterDeg - gt).^2));
            errStr = sprintf('%8.2f', err);
            errVec = [errVec; err]; %#ok<AGROW>
        end
        fprintf('  %2d | %7.1f | %6d | %s | %s | %s | %s\n', ...
            ch, q.spatialSNR, q.spikeCount, centerStr, gtStr, errStr, ...
            passStr(q.passGo));
    else
        reasons = '';
        if ~isempty(q.failReasons)
            reasons = strjoin(q.failReasons, ', ');
        end
        fprintf('  %2d | %7.1f | %6d | %s | %s | %s\n', ...
            ch, q.spatialSNR, q.spikeCount, centerStr, ...
            passStr(q.passGo), reasons);
    end
end

fprintf('\n  Channels passing quality: %d / %d with spikes\n', nPass, nCh);
if ~isempty(errVec)
    fprintf('  Median center error: %.2f dva (%.2f checks)\n', ...
        median(errVec), median(errVec) / p.trVars.checkSizeDeg);
end
fprintf('=== END EVALUATION ===\n\n');

% Store on p for downstream use.
p.status.rfQuality = quality;
p.status.rfQualityNPass = nPass;

end


function s = passStr(tf)
if tf, s = 'PASS'; else, s = 'FAIL'; end
end
