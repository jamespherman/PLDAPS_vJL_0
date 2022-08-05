function p = catOldOutput(p)

% prompt user to select a new output directory
newOutputFolderName = uigetdir('', ...
    'Select an output folder...');

% tell user we're loading data
disp('Loading data...');

% load session's data
q = pds.loadP(newOutputFolderName);

% tell user we're saving session's data
disp('Saving session data...');

% save session data
t = find(newOutputFolderName == filesep, 1, 'last');
sessionFileName = [newOutputFolderName(1:t) ...
    newOutputFolderName(t+1:end) '.mat'];
save(sessionFileName, '-struct', 'q');
[~, lmid] = lastwarn;
if strcmp(lmid, 'MATLAB:save:sizeTooBigForMATFile')
    save(sessionFileName, '-v7.3', '-struct', 'q');
end

% tell user we're back to "idle"
disp('Done saving.');
end