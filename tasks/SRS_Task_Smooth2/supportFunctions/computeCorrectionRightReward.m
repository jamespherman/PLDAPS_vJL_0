function rewardMs = computeCorrectionRightReward( ...
    originalRewardMs, multiplier, reductionLevel, minimumRewardMs)
%COMPUTECORRECTIONRIGHTREWARD Compute cumulative RIGHT correction reward.
%
% Example with original=100, multiplier=0.5, minimum=10:
%   level 1 -> 50 ms
%   level 2 -> 25 ms
%   level 3 -> 12 ms
%   level 4 -> 10 ms (minimum)

validateattributes(originalRewardMs, {'numeric'}, ...
    {'real','finite','scalar','nonnegative'}, mfilename, 'originalRewardMs');
validateattributes(multiplier, {'numeric'}, ...
    {'real','finite','scalar','>=',0,'<=',1}, mfilename, 'multiplier');
validateattributes(reductionLevel, {'numeric'}, ...
    {'real','finite','scalar','integer','nonnegative'}, ...
    mfilename, 'reductionLevel');
validateattributes(minimumRewardMs, {'numeric'}, ...
    {'real','finite','scalar','nonnegative'}, mfilename, 'minimumRewardMs');

originalRewardMs = round(double(originalRewardMs));
reductionLevel = round(double(reductionLevel));
minimumRewardMs = round(double(minimumRewardMs));

% A configured minimum above the original reward must not accidentally
% increase a low reward.
effectiveMinimumMs = min(originalRewardMs, minimumRewardMs);
scaledRewardMs = floor(originalRewardMs * double(multiplier)^reductionLevel);
rewardMs = max(effectiveMinimumMs, scaledRewardMs);

end
