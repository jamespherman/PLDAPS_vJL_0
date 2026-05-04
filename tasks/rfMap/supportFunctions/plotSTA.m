function plotSTA(stimType, figData, staAccum, staSpikeCount, selectedChannel)
% plotSTA  Stim-type dispatcher for online STA plotting.
%
%   plotSTA(stimType, figData, staAccum, staSpikeCount, selectedChannel)
%
%   Routes to the per-stim-type plotter:
%     'denseAchromatic'  ->  plotSTA_spatial (nAxes = 1)
%     'sparse'           ->  plotSTA_spatial (nAxes = 1)
%     'denseChromatic'   ->  plotSTA_spatial (nAxes = 3, Phase 2 will activate)
%     'checkerboard'     ->  plotSTA_checkerboard (Phase 3 stub)

if nargin < 5 || isempty(selectedChannel), selectedChannel = 1; end

switch stimType
    case {'denseAchromatic', 'sparse'}
        plotSTA_spatial(figData, staAccum, staSpikeCount, selectedChannel, 1);

    case 'denseChromatic'
        plotSTA_spatial(figData, staAccum, staSpikeCount, selectedChannel, 3);

    case 'checkerboard'
        plotSTA_checkerboard(figData, staAccum, staSpikeCount, selectedChannel);

    otherwise
        error('plotSTA:badStimType', ...
            ['Unrecognized stimType ''%s''. Expected one of: ' ...
             'denseAchromatic, denseChromatic, sparse, checkerboard.'], ...
            stimType);
end

end
