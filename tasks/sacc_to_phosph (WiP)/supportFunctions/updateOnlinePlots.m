function p               = updateOnlinePlots(p)
% p = updateOnlinePlots(p)
%
% Update the data shown in on-line plots


if strcmp(p.init.exptType, 'pick_one_channel')

    microstimHits = p.status.microstimNumHits (p.trVars.stimulatedElectrode, :);

    microstimTotal = p.status.microstimNumHits (p.trVars.stimulatedElectrode, :) + ...
        p.status.microstimNumMisses (p.trVars.stimulatedElectrode, :);

    p.draw.onlinePlotPsychoData.YData = microstimHits./microstimTotal;

    title(p.draw.onlinePlotPsychoAxes, ['On-line Psychometric Curve for electrode #' num2str(p.trVars.stimulatedElectrode)]);


elseif strcmp(p.init.exptType, 'pick_all_channels')

    microstimHits = p.status.microstimNumHits (p.trVars.stimListIndex, :);

    microstimTotal = p.status.microstimNumHits (p.trVars.stimListIndex, :) + ...
        p.status.microstimNumMisses (p.trVars.stimListIndex, :);

    p.draw.onlinePlotPsychoData.YData = microstimHits/microstimTotal;

    title(p.draw.onlinePlotPsychoAxes, ['On-line Psychometric Curve for electrode set #' num2str(p.trVars.stimListIndex)]);

end

p.draw.onlinePlotPsychoFARate.Value = p.status.falseAlarms / (p.status.falseAlarms + p.status.correctRejects);


end