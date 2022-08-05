function p = openPortToServer(p)

% initialize connection to plexon PC:
% (1) delete any existing TCPIP connetions
% (2) define port number and IP address of connection
% (3) create TCPIP object
delete(instrfindall);
portNum = 30000;
p.rig.tcpipObj = tcpip('128.231.132.88', portNum, 'NetworkRole', 'client');

% adjust input and output bufer sizes
p.rig.tcpipObj.InputBufferSize = 8^8;
p.rig.tcpipObj.OutputBufferSize = 8^8;

% set "bytes available function" so that whenever data comes in, it is
% stored.
p.rig.tcpipObj.BytesAvailableFcnMode = 'Terminator';
p.rig.tcpipObj.BytesAvailableFcn = @bytesAvailableFunction;

% open port
fopen(p.rig.tcpipObj);

end

function bytesAvailableFunction(object, event)

% if there's data to be read, read it and store it.
if object.BytesAvailable > 0
    object.UserData = [object.UserData; ...
        fread(object, object.BytesAvailable/8, 'double')];
end

end