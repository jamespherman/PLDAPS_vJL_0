function delayMs = sampleTargetDelayMs(minDelayMs, maxDelayMs, previousDelayMs)
%SAMPLETARGETDELAYMS Sample one stable delay for the upcoming trial.
%
% Sampling is uniform over integer milliseconds in the inclusive range.
% When the range contains at least two values, the immediately preceding
% delay is excluded so consecutive trials always have different go times.

if nargin < 3
    previousDelayMs = NaN;
end
validateattributes(minDelayMs, {'numeric'}, ...
    {'real','finite','scalar','nonnegative'}, mfilename, 'minDelayMs');
validateattributes(maxDelayMs, {'numeric'}, ...
    {'real','finite','scalar','nonnegative','>=',minDelayMs}, ...
    mfilename, 'maxDelayMs');

firstMs = ceil(double(minDelayMs));
lastMs = floor(double(maxDelayMs));
if firstMs > lastMs
    error('SRS:NoIntegerTargetDelay', ...
        'The requested delay interval contains no integer millisecond.');
end

nValues = lastMs - firstMs + 1;
previousIsCandidate = isscalar(previousDelayMs) && ...
    isnumeric(previousDelayMs) && isfinite(double(previousDelayMs)) && ...
    previousDelayMs == round(previousDelayMs) && ...
    previousDelayMs >= firstMs && previousDelayMs <= lastMs;

if nValues == 1
    delayMs = firstMs;
elseif previousIsCandidate
    % Draw uniformly from every value except the immediately previous one.
    drawIndex = randi(nValues - 1) - 1;
    previousIndex = double(previousDelayMs) - firstMs;
    if drawIndex >= previousIndex
        drawIndex = drawIndex + 1;
    end
    delayMs = firstMs + drawIndex;
else
    delayMs = randi([firstMs, lastMs]);
end

end
