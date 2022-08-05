function tCor = correctForLatency(t, y, rig)
%   tCor = pds.correctForLatency(t, y, rig)
%
% Given latnecies that are inherent to your hardware, this function
% corrects timing meausrements.
% 
% INPUT:
%   t - Time an event occured (in seconds). Can be a vector.
%   y - y-position of the event on the screen (in pixels, where 1 is top 
%       and n (e.g. 1200) is bottom. Can be a vector.
%   rig - string input defning the rig you're on. Each rig gets assigned a
%       latencyStrobeToScreen & latencyTopToBottom. See below for details.
%       User Must input the apropriate values within the switch loop.
%
% OUTPUT:
%   tCor - time of event, after having been corrected for the latencies.

if ~exist('rig', 'var')
    rig = 'rigA_viewpixx';
end

%% Each rig/monitor setup has 2 important values:
%
% latencyStrobeToScreen - 
%   This is the time elapsed from moment we strobed that something has been 
%   drawn on screen and until the screen physiclaly changed. We measure 
%   this with a photodiode. See details in the functions:
%       PTB_machine_photodiodeTime_vs_flipTime.m
%       DAQ_machine_photodiodeTime_vs_strobeTime.m
%
% latencyTopToBottom - 
%   This is the time elapsed from the moment the top of the screen
%   physically changed and until the bottom has changed. Measured by
%   placing the photodiode at top and then bottom, see the above functions
%   for details.
   
assert(numel(y)==numel(t), 'ERROR: number of elements in t must match number of elements in y');

y       = y(:);
n       = numel(y);
tCor    = nan(n, 1);

switch rig
    case 'rigA_viewpixx'
        latencyStrobeToScreen   = 0.0087;   % in seconds   
        latencyTopToBottom      = 0.008;    % in seconds
        
        % compute latency for any given verticla location on screen:
        nPixels         = 1200;     % number of pixels rows in the monitor
        nLedRows        = 8;       % number of LED rows that light up the pixels
        rowLatency      = (latencyTopToBottom / (nLedRows-1)) * (0:(nLedRows-1)); % latency per row, from top to bottom   
        % which row is this pixel at?
        
        for ii = 1:numel(y)
            [~, rowNum] = histc(y(ii), linspace(0,nPixels, (nLedRows + 1)) + 1);
            assert(numel(rowNum)==1, 'somehow your pixel value matched two rows. inconceivable');
            tCor(ii)    = t(ii) - latencyStrobeToScreen - rowLatency(rowNum);
        end
        
    otherwise
        error('Must define rig. Or suffer the consequences')
end



