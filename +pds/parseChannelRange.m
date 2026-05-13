function chans = parseChannelRange(str, nCh)
% pds.parseChannelRange  Parse "1-16, 33, 40-50" into a sorted unique vector.
%
%   chans = pds.parseChannelRange(str, nCh)
%
%   Accepts tokens separated by commas, semicolons, or whitespace. Each
%   token is either a single channel ("33") or an inclusive range
%   ("40-50"). Tokens outside [1, nCh] are clipped silently; invalid
%   tokens are skipped. Returns a row vector of channel indices in
%   ascending order with duplicates removed.
%
%   Empty / whitespace-only input returns []. Used by the channel-browser
%   range-edit control to translate user text into a numeric selection
%   vector that the listbox can mirror.

if nargin < 2 || isempty(nCh), nCh = inf; end
chans = [];

if isempty(str) || all(isspace(str))
    return;
end

% Split on commas/semicolons; whitespace inside a token is tolerated.
toks = regexp(str, '[,;]', 'split');
acc = [];
for k = 1:numel(toks)
    t = strtrim(toks{k});
    if isempty(t), continue; end

    % Range form: "a-b" (also tolerates ":" as separator).
    rng = regexp(t, '^\s*(\d+)\s*[-:]\s*(\d+)\s*$', 'tokens', 'once');
    if ~isempty(rng)
        a = str2double(rng{1});
        b = str2double(rng{2});
        if isfinite(a) && isfinite(b)
            if a > b, tmp = a; a = b; b = tmp; end
            acc = [acc, a:b]; %#ok<AGROW>
        end
        continue;
    end

    % Single number.
    n = sscanf(t, '%d', 1);
    if ~isempty(n) && isfinite(n)
        acc = [acc, n]; %#ok<AGROW>
    end
end

if isempty(acc)
    return;
end

acc = round(acc(:)');
acc = acc(acc >= 1 & acc <= nCh);
chans = unique(acc);

end
