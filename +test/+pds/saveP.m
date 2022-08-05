function [] = saveP(p)
%   p = saveP(p)
% 
% Saves the output of a pldaps_vK2 session to the task's sessionFolder
% (defined in the settings file under p.init.sessionFolder)
% First, saves 'p' struct on trial 1 (and on trial 1 only!) to 'p file'.
% Then, saves p.trVars & p.trData on every trial into a 'trial file'.
%
% Input:
%   p - your regular ol' pldaps_vk2 'p' struct
%
% See also pds.loadP


%% saveP (folder)

if ~exist(p.init.sessionFolder, 'dir')
    mkdir(p.init.sessionFolder)
end

% on trial 1, save the 'p' struct into 'pFile'.
if p.status.iTrial == 1
    save(fullfile(p.init.sessionFolder, 'p.mat'), '-struct', 'p'); % saving only substructs so I may load directly into 'p', see pds.loadP.
end

% on all trials, save trVars & trData IFF subject actually started trial:
if p.trData.trialEndState == p.state.nonStart
    return;
end

save(fullfile(p.init.sessionFolder, 'p.mat'), '-struct', 'p','status','-append') % for save latest status a kind of behavioral summary 04/11/19 YGC


% save trial file:
iString = sprintf('%04d', p.status.iTrial); % add leading zeros to make a 4 digit string for the trial number.
trVars  = p.trVars;
trData  = p.trData;
save(fullfile(p.init.sessionFolder, ['trial' iString '.mat']), 'trVars', 'trData');

