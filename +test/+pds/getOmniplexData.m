function p = getOmniplexData(p)

% p = getOmniplexData(p)
%
% use TCP/IP connection to omniplex PC MATLAB instance to retreive spike
% and event times from omniplex PC.

% keyboard

% empty the ad-hoc "buffer" we've created in the TCP/IP object
p.rig.tcpipObj.UserData = [];

% trigger omniplex MATLAB to get data from omniplex server and send HERE
fwrite(p.rig.tcpipObj, '0', 'uchar');

% wait for data buffer to fill
while isempty(p.rig.tcpipObj.UserData)
    WaitSecs(0.01);
end

% how many values did we get? This "should" be a multiple of 4. In case it
% isn't, round down to the nearest multiple of 4.
nCols = 4;
nRows = fix(numel(p.rig.tcpipObj.UserData) / nCols);
nValues = nCols * nRows;

% reshape vector into n x 4 array and store
p.trData.spikeAndStrobeTimes = reshape(...
    p.rig.tcpipObj.UserData(1:nValues), nRows, nCols);

end