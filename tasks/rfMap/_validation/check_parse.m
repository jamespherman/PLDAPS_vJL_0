projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
try, which('computeRFCenters'); fprintf('computeRFCenters: OK\n'); catch e, fprintf('ERR: %s\n', e.message); end
try, which('nextParams'); fprintf('nextParams: OK\n'); catch e, fprintf('ERR: %s\n', e.message); end
try, which('simInitKernelBank'); fprintf('simInitKernelBank: OK\n'); catch e, fprintf('ERR: %s\n', e.message); end
try, which('simulateRippleData'); fprintf('simulateRippleData: OK\n'); catch e, fprintf('ERR: %s\n', e.message); end
try
    c = pds.initCodes;
    fprintf('initCodes: OK (%d codes, rfMapStimHemifield=%d)\n', ...
        numel(fieldnames(c)), c.rfMapStimHemifield);
catch e
    fprintf('initCodes ERR: %s\n', e.message);
end
exit;
