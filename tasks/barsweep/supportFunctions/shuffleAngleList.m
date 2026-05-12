function out = shuffleAngleList(angleList, pairShuffle)
% out = shuffleAngleList(angleList, pairShuffle)
%
% Build a shuffled order over angleList for the barsweep schedule pool.
%
%   pairShuffle = false (legacy): full randperm(numel(angleList)).
%   pairShuffle = true:  draw opposite-direction pairs as a unit so every
%       (theta, theta+180) pair completes within two trials. Pairs are
%       randomized; within each pair the order is randomized too. This
%       tightens the §2 forward/reverse balance window from "many trials"
%       to one trial in flight at any time, which makes the latency-
%       cancellation assumption hold even early in a session.
%
% Falls back to legacy randperm if the angle list does not partition into
% opposite-direction pairs (e.g. an odd count, or any angle missing its
% theta+180 mate). Avoids silently mis-scheduling a non-paired angle list.

if nargin < 2 || ~pairShuffle
    out = angleList(randperm(numel(angleList)));
    return;
end

n = numel(angleList);
if mod(n, 2) ~= 0
    out = angleList(randperm(n));
    return;
end

% Identify pairs: for each angle, find its (a + 180) mod 360 mate.
unused = true(1, n);
pairs = zeros(n / 2, 2);
nPairs = 0;
for i = 1:n
    if ~unused(i), continue; end
    target = mod(angleList(i) + 180, 360);
    j = find(unused & abs(mod(angleList - target, 360)) < 1e-6, 1);
    if isempty(j) || j == i
        % No mate -> bail out and fall back to plain randperm.
        out = angleList(randperm(n));
        return;
    end
    nPairs = nPairs + 1;
    pairs(nPairs, :) = [angleList(i), angleList(j)];
    unused(i) = false;
    unused(j) = false;
end

% Shuffle the pair order, and randomize within each pair.
pairs = pairs(randperm(nPairs), :);
for k = 1:nPairs
    if rand < 0.5
        pairs(k, :) = pairs(k, [2, 1]);
    end
end

out = reshape(pairs', 1, []);

end
