function [p] = summarizeBehaviorBasic(p)
%   [] = summarizeBehaviorBasic(p)

fprintf('\rSummarizing sessionId: %s...\r', p.init.sessionId)
%% basic behavior (bb):

bb = analyzeBehaviorBasic(p);

% analyze RT:
%analyze trial completion over time
% progress over time, and an attempt to identify at which trial type he pauses.

%%
% save analysis output 'bb':
save(fullfile(p.init.outputFolder, [p.init.sessionId '_bb.mat']), 'bb');

%% mkfig for plotting basic behavior

hFig = mkfig.behaviorBasic(bb);

% and save:
if ~isfield(p.init, 'figureFolder')
    p.init.figureFolder = fullfile(p.init.outputFolder, 'figures');
end
saveas(hFig, fullfile(p.init.figureFolder, [p.init.sessionId '.pdf']));

%%

disp('Done!')
