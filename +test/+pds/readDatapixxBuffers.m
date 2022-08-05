function p = readDatapixxBuffers(p)

%%% Read continuously sampled eye & joystick voltages and digital inputs
%%% (spike times or other).

% Update registers for GetAdcStatus
Datapixx('RegWrRd');

% get VIEWPixx ADC status.
ADCstatus              = Datapixx('GetAdcStatus');

% How many samples available to read?
nReadAdcSpls           = ADCstatus.newBufferFrames;

% Read ADC buffer.
[LocalADCbuffer(1:4,1:nReadAdcSpls), LocalADCbuffer(5,1:nReadAdcSpls)]  = Datapixx('ReadAdcBuffer', nReadAdcSpls, p.rig.dp.adcBuffAddr);

% Stop ADC schedule.
Datapixx('StopAdcSchedule');
Datapixx('RegWrRd');

% Update registers for GetDinStatus
Datapixx('RegWrRd');

% get VIEWPixx ADC status.
DINstatus           = Datapixx('GetDinStatus');

% Read Data
[p.trData.dInValues, p.trData.dInTimes] = Datapixx('ReadDinLog', DINstatus.newLogFrames);

% Stop DIN schedule.
Datapixx('StopDinLog');
Datapixx('RegWrRd');

p.trData.eyeX = LocalADCbuffer(1, :);
p.trData.eyeY = LocalADCbuffer(2, :);
p.trData.eyeP = LocalADCbuffer(3, :);
p.trData.joyV = LocalADCbuffer(4, :);
p.trData.eyeT = LocalADCbuffer(5, :);

end