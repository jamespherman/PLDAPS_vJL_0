function nextLevel = advanceCorrectionRightRewardReductionLevel( ...
    currentLevel, trialCompleted, chosenSide, choseHighReward)
%ADVANCECORRECTIONRIGHTREWARDREDUCTIONLEVEL Update cumulative reduction.
%
% Advance only after a completed, still-incorrect RIGHT choice. Aborted
% attempts (fixation break, no response, invalid landing, and so on) leave
% the reduction level unchanged.

validateattributes(currentLevel, {'numeric'}, ...
    {'real','finite','scalar','integer','nonnegative'}, ...
    mfilename, 'currentLevel');

nextLevel = round(double(currentLevel));
if logical(trialCompleted) && chosenSide == 1 && ~logical(choseHighReward)
    nextLevel = nextLevel + 1;
end

end
