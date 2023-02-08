function hFig = behaviorBasic(bb)
%   hFig = mkfig.behaviorBasic(bb)
%
% makes a figure for the behaviorBasic analysis (hit/fa rates etc)
%
% INPUT
%   bb - the behaviorBasic ('bb') struct which is the output of 
%        analyzeBehaviorBasic.m
%
% OUTPUT
%   hFig - hanle to figure
%
% see also analyzeBehaviorBasic.m


hFig    = figure;
figSize = [6 6];

% for stim n = 2
iN = 2;
subplot(221); hold on;
hA = plot_hitP_foilFaP(bb.n(iN).cue, bb.n(iN).foil);
title('n = 2')

subplot(222); hold on;
hA = plot_hitP_foilFaP_perLoc(bb.n(iN).cue, bb.n(iN).foil);
title('n = 2')

% for stim n = 1
iN = 1;
subplot(223); hold on;
hA = plot_hitP_foilFaP(bb.n(iN).cue, bb.n(iN).foil);
title('n = 1')

subplot(224); hold on;
hA = plot_hitP_foilFaP_perLoc(bb.n(iN).cue, bb.n(iN).foil);
title('n = 1')

pds.formatFig(hFig, figSize);

