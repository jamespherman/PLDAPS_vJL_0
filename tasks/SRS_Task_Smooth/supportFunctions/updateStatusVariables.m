function p = updateStatusVariables(p)
%UPDATESTATUSVARIABLES Update successful-trial and outcome counters.

p.status.iGoodTrial = p.status.iGoodTrial + double(p.trData.GoodTrial);

if p.trData.GoodTrial
    if p.trVars.nStim == 1
        % Instruction trials are counted separately and do not contribute
        % to conflict/congruent choice statistics.
        if p.trVars.singleTargetID == 1
            p.status.iSingleT1Correct = p.status.iSingleT1Correct + 1;
        elseif p.trVars.singleTargetID == 2
            p.status.iSingleT2Correct = p.status.iSingleT2Correct + 1;
        end

    elseif p.trVars.nStim == 2
        % Choice-trial outcome counters.
        if p.status.ActualTrialType == 1
            % Congruent: rich and high salience refer to the same target.
            if p.trData.chosenTargetID == p.status.highRewardTargetID
                p.status.iTrial_Rich_High = p.status.iTrial_Rich_High + 1;
            else
                p.status.iTrial_Poor_low = p.status.iTrial_Poor_low + 1;
            end

        elseif p.status.ActualTrialType == 2
            % Conflict: rich is low salience and poor is high salience.
            if p.trData.chosenTargetID == p.status.highRewardTargetID
                p.status.iTrial_Rich_low = p.status.iTrial_Rich_low + 1;
            else
                p.status.iTrial_Poor_High = p.status.iTrial_Poor_High + 1;
            end
        end
    end
end

if p.trVars.useQuest
    p.status.questThreshEst = 10^QuestMean(p.init.questObj);
end

end
