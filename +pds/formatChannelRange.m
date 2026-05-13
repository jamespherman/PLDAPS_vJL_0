function str = formatChannelRange(chans)
% pds.formatChannelRange  Compact a channel vector into "1-3, 5, 7-9".
%
%   str = pds.formatChannelRange(chans)
%
%   Inverse of pds.parseChannelRange (up to formatting): contiguous runs
%   collapse to "a-b", isolated channels stay as "n", everything is
%   joined with ", ". Empty input returns ''.

if isempty(chans)
    str = '';
    return;
end

c = unique(round(chans(:)'));
% Find boundaries between runs of consecutive integers.
breaks = [0, find(diff(c) ~= 1), numel(c)];
parts  = cell(1, numel(breaks) - 1);
for k = 1:numel(breaks) - 1
    a = c(breaks(k) + 1);
    b = c(breaks(k + 1));
    if a == b
        parts{k} = sprintf('%d', a);
    else
        parts{k} = sprintf('%d-%d', a, b);
    end
end
str = strjoin(parts, ', ');

end
