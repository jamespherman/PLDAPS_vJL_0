function p = loadP(sessionFolder)
%   p = loadP(sessionFolder)
% 
% loads the output of a pldaps_vK2 session to memory. 
% first it loads the general 'p file' (holds all task info) and then loads
% each 'trial file' into two strcut arrays: trVars & trData, each of length
% nTrials. 
%
% Input:
%   sessionFolder - path to the folder that holds output of the session.
%                   This folder should have one 'p' file and many 'trial'
%                   files, save by saveP.
%   no input      - function will open ui box for you to select a folder.
% 
% Output:
%   single 'p' struct that holds all general and trial-by-trial data.
%
% See also pds.saveP


%% find files of interst:

% if session Folder was not provided as input, have user select one:
if ~exist('sessionFolder', 'var')
    [sessionFolder] = uigetdir(pwd, 'Select the session folder you wish to load');
end

% get all files in folder, but only .mat files:
fileList = dir(sessionFolder);
idxMat      = arrayfun(@(x) any(strfind(x.name, '.mat')), fileList);
fileList    = fileList(idxMat);

% get indices to the one 'p' file:
idxP      = find(arrayfun(@(x) any(strfind(x.name, 'p.mat')), fileList));
% get pointer to all 'trial' files:
idxTrial  = find(arrayfun(@(x) any(strfind(x.name, 'trial') & strfind(x.name, '.mat')), fileList));

%% Load'em up:

% load the 'p file' into 'p':
p = load(fullfile(sessionFolder, fileList(idxP).name));

% load each 'trial file' into a struct array:
nTrials = numel(idxTrial);
for iTr = 1:nTrials
    filePath = fullfile(sessionFolder, fileList(idxTrial(iTr)).name);
    tmp = load(filePath);
    
    p.trVars(iTr,1) = tmp.trVars;
    p.trData(iTr,1) = tmp.trData;
end