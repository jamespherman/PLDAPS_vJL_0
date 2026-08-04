function p = i1ScanRedRgbDirect(p, varargin)
%I1SCANREDRGBDIRECT Measure dark-red ramps defined directly in RGB space.
%
% Each ramp has fixed G/R and B/R ratios while red-channel intensity
% increases. Colors are drawn as direct [R G B] triplets, without the task
% CLUT and without DKL conversion. The i1Pro measurements are used to rank
% ramps whose endpoints best approximate 0.01 and 12.15 cd/m^2.
%
% Run after task initialization from the PLDAPS GUI Actions menu. Do not run
% during behavioral trials.
%
% Optional name/value inputs:
%   'profile'     : 'quick' (default) or 'full'
%   'nRepeats'    : measurements per unique RGB triplet (default 1)
%   'settleTime'  : seconds after Screen flip (default 0.20)
%   'targetLow'   : desired low luminance cd/m^2 (default 0.01)
%   'targetHigh'  : desired high luminance cd/m^2 (default 12.15)
%   'i1Path'      : folder containing I1.mexa64

opts = parseOptions(p, varargin{:});
assertTaskWindow(p);
addI1Path(opts.i1Path);
calibrateI1;

[candidateTable, familyTable, uniqueRgbTable, candidateToUnique] = ...
    makeDirectRgbCandidates(opts.profile);
fprintf('Direct RGB scan: %d candidate rows, %d unique RGB colors, %d families.\n', ...
    height(candidateTable),height(uniqueRgbTable),height(familyTable));
fprintf('Approximate minimum acquisition time: %.1f minutes.\n', ...
    height(uniqueRgbTable)*opts.nRepeats*opts.settleTime/60);

% L48 interprets the red channel as a CLUT row. Temporarily reopen the
% display in C24 so each test triplet is measured as genuine direct RGB.
p = enterC24RgbMode(p);
try
    uniqueMeasurements = measureRgbTable(p,uniqueRgbTable,opts);
catch measurementError
    p = restoreL48TaskMode(p);
    rethrow(measurementError);
end
p = restoreL48TaskMode(p);
[candidateTable,familySummary,bestLow,bestHigh] = ...
    summarizeMeasurements(candidateTable,uniqueMeasurements, ...
    candidateToUnique,opts.targetLow,opts.targetHigh);

result=struct();
result.candidates=candidateTable;
result.families=familyTable;
result.uniqueRgb=uniqueRgbTable;
result.familySummary=familySummary;
result.bestLow=bestLow;
result.bestHigh=bestHigh;
result.rawUniqueMeasurements=uniqueMeasurements;
result.options=opts;
result.createdAt=datestr(now,30);
p.rig.displayCal.directRedRgbScan=result;

saveResult(p,result,'i1_direct_red_rgb_scan');
showResults(candidateTable,familySummary,bestLow,bestHigh,opts);

fprintf('\nBest direct-RGB red family found:\n');
disp(bestLow(:,{'familyID','gOverR','bOverR','redLevel', ...
    'rgbR_255','rgbG_255','rgbB_255','measuredCdM2'}));
disp(bestHigh(:,{'familyID','gOverR','bOverR','redLevel', ...
    'rgbR_255','rgbG_255','rgbB_255','measuredCdM2'}));
fprintf(['Confirm the chosen RGB endpoints with a denser dedicated ramp ', ...
    'measurement before using them in a behavioral CLUT.\n']);
end

function opts=parseOptions(p,varargin)
opts.profile='quick'; opts.nRepeats=1; opts.settleTime=0.20;
opts.targetLow=0.01; opts.targetHigh=12.15;
opts.i1Path='/home/herman_lab/OneDrive/Code/i1';
config = struct();
if isfield(p, 'trVars'), config = p.trVars; elseif isfield(p, 'trVarsInit'), config = p.trVarsInit; end
if isfield(config, 'redRgbScanProfile'), opts.profile = lower(char(config.redRgbScanProfile)); end
if isfield(config, 'redRgbScanNRepeats'), opts.nRepeats = config.redRgbScanNRepeats; end
if isfield(config, 'redRgbScanSettleTime'), opts.settleTime = config.redRgbScanSettleTime; end
if isfield(config, 'redRgbScanTargetLowCdM2'), opts.targetLow = config.redRgbScanTargetLowCdM2; end
if isfield(config, 'redRgbScanTargetHighCdM2'), opts.targetHigh = config.redRgbScanTargetHighCdM2; end
if mod(numel(varargin),2)~=0
    error('Optional inputs must be name/value pairs.');
end
for i=1:2:numel(varargin)
    name=lower(char(varargin{i})); value=varargin{i+1};
    switch name
        case 'profile', opts.profile=lower(char(value));
        case 'nrepeats', opts.nRepeats=value;
        case 'settletime', opts.settleTime=value;
        case 'targetlow', opts.targetLow=value;
        case 'targethigh', opts.targetHigh=value;
        case 'i1path', opts.i1Path=char(value);
        otherwise, error('Unknown option: %s',name);
    end
end
validateattributes(opts.nRepeats,{'numeric'},{'scalar','integer','positive'});
validateattributes(opts.settleTime,{'numeric'},{'scalar','nonnegative','finite'});
validateattributes(opts.targetLow,{'numeric'},{'scalar','nonnegative','finite'});
validateattributes(opts.targetHigh,{'numeric'}, ...
    {'scalar','positive','finite','>',opts.targetLow});
if ~any(strcmp(opts.profile,{'quick','full'}))
    error('profile must be ''quick'' or ''full''.');
end
end

function assertTaskWindow(p)
if ~isfield(p,'draw') || ~isfield(p.draw,'window') || isempty(p.draw.window)
    error('Initialize the task first so p.draw.window exists.');
end
end

function addI1Path(i1Path)
if exist(i1Path,'dir'), addpath(i1Path); rehash; end
if exist('I1','file')~=2 && exist('I1','file')~=3
    error('I1.mexa64 was not found. Expected folder: %s',i1Path);
end
end

function calibrateI1
if ~I1('IsConnected')
    error('The i1Pro is not connected or not detected by I1.mexa64.');
end
disp('Place photometer in calibration cradle, then press any keyboard key.');
pause; I1('Calibrate'); disp('i1 calibration complete.');
disp('Place photometer on the screen, then press any keyboard key.');
pause;
end

function [candidates,families,uniqueRgb,candidateToUnique] = ...
        makeDirectRgbCandidates(profile)
if strcmp(profile,'quick')
    gRatios=[0 0.03 0.08];
    bRatios=[0 0.10 0.20 0.34 0.50];
    redLevels=0:8:255;
    if redLevels(end)~=255, redLevels(end+1)=255; end
else
    gRatios=[0 0.02 0.04 0.06 0.08 0.10 0.15 0.20];
    bRatios=[0 0.05 0.10 0.15 0.20 0.25 0.34 0.40 0.50 0.60];
    redLevels=0:4:255;
    if redLevels(end)~=255, redLevels(end+1)=255; end
end

familyID=[]; gCol=[]; bCol=[]; id=0;
for g=gRatios
    for b=bRatios
        if g>=1 || b>=1, continue; end
        id=id+1; familyID(end+1,1)=id; gCol(end+1,1)=g; bCol(end+1,1)=b; %#ok<AGROW>
    end
end
families=table(familyID,gCol,bCol,'VariableNames', ...
    {'familyID','gOverR','bOverR'});

rows=zeros(0,8);
for i=1:height(families)
    for r=redLevels
        g=round(families.gOverR(i)*r);
        b=round(families.bOverR(i)*r);
        if r<g || r<b, continue; end
        redness=(double(r)-max(double([g b])))/255;
        rows(end+1,:)=[families.familyID(i),families.gOverR(i), ...
            families.bOverR(i),r,r,g,b,redness]; %#ok<AGROW>
    end
end
candidates=array2table(rows,'VariableNames',{'familyID','gOverR','bOverR', ...
    'redLevel','rgbR_255','rgbG_255','rgbB_255','redDominance'});

rgbMatrix=[candidates.rgbR_255,candidates.rgbG_255,candidates.rgbB_255];
[uniqueMatrix,~,candidateToUnique]=unique(rgbMatrix,'rows','stable');
uniqueRgb=array2table(uniqueMatrix,'VariableNames', ...
    {'rgbR_255','rgbG_255','rgbB_255'});
end

function measurements=measureRgbTable(p,t,opts)
n=height(t); measurements=nan(3,n,opts.nRepeats);
hWait=waitbar(0,'Measuring direct RGB red candidates...');
cleanup=onCleanup(@()safeCloseWaitbar(hWait)); %#ok<NASGU>
for iRepeat=1:opts.nRepeats
    for i=1:n
        abortIfEscape;
        rgb=[t.rgbR_255(i),t.rgbG_255(i),t.rgbB_255(i)];
        Screen('FillRect',p.draw.window,rgb); Screen('Flip',p.draw.window);
        WaitSecs(opts.settleTime);
        I1('TriggerMeasurement'); measurements(:,i,iRepeat)=I1('GetTriStimulus');
        waitbar(((iRepeat-1)*n+i)/(opts.nRepeats*n),hWait);
        if mod(i,25)==0 || i==n
            fprintf('Direct RGB scan repeat %d/%d: %d/%d unique colors.\n', ...
                iRepeat,opts.nRepeats,i,n);
        end
    end
end
end

function [candidates,summary,bestLow,bestHigh]=summarizeMeasurements( ...
        candidates,uniqueMeasurements,map,targetLow,targetHigh)
meanM=mean(uniqueMeasurements,3,'omitnan');
sdM=std(uniqueMeasurements,0,3,'omitnan');
candidates.measuredCdM2=meanM(1,map)';
candidates.measuredCdM2Sd=sdM(1,map)';
candidates.cieX=meanM(2,map)'; candidates.cieY=meanM(3,map)';
ids=unique(candidates.familyID,'stable'); rows=nan(numel(ids),12);
for k=1:numel(ids)
    id=ids(k); t=candidates(candidates.familyID==id,:);
    [~,o]=sort(t.redLevel); t=t(o,:);
    mono=mean(diff(t.measuredCdM2)>=-0.05);
    [iLow,iHigh,score]=bestEndpointPair(t.measuredCdM2,targetLow,targetHigh);
    rows(k,:)=[id,t.gOverR(1),t.bOverR(1),height(t),mono,iLow,iHigh, ...
        t.redLevel(iLow),t.redLevel(iHigh),t.measuredCdM2(iLow), ...
        t.measuredCdM2(iHigh),score];
end
summary=array2table(rows,'VariableNames',{'familyID','gOverR','bOverR', ...
    'nMeasured','monotonicFraction','lowLocalIndex','highLocalIndex', ...
    'lowRedLevel','highRedLevel','lowCdM2','highCdM2','score'});
summary=summary(isfinite(summary.score),:);
summary.spanCdM2=summary.highCdM2-summary.lowCdM2;
summary.score=summary.score+25*max(0,0.95-summary.monotonicFraction);
summary=sortrows(summary,'score','ascend');
if isempty(summary), error('No direct RGB family had two valid points.'); end
bestID=summary.familyID(1); t=candidates(candidates.familyID==bestID,:);
[~,o]=sort(t.redLevel); t=t(o,:);
[iLow,iHigh]=bestEndpointPair(t.measuredCdM2,targetLow,targetHigh);
bestLow=t(iLow,:); bestHigh=t(iHigh,:);
end

function [bestLow,bestHigh,bestScore]=bestEndpointPair(y,targetLow,targetHigh)
bestScore=inf; bestLow=1; bestHigh=numel(y);
for i=1:numel(y)-1
    for j=i+1:numel(y)
        if ~isfinite(y(i)) || ~isfinite(y(j)) || y(j)<=y(i), continue; end
        score=abs(y(i)-targetLow)+abs(y(j)-targetHigh);
        if score<bestScore, bestScore=score; bestLow=i; bestHigh=j; end
    end
end
end

function saveResult(p,result,tag)
if isfield(p,'init') && isfield(p.init,'outputFolder'), outDir=p.init.outputFolder; else, outDir=pwd; end
if ~exist(outDir,'dir'), mkdir(outDir); end
if isfield(p,'init') && isfield(p.init,'sessionId'), stem=[p.init.sessionId '_' tag]; else, stem=[datestr(now,'yyyymmdd_HHMMSS') '_' tag]; end
save(fullfile(outDir,[stem '.mat']),'result','-v7.3');
writetable(result.candidates,fullfile(outDir,[stem '_candidates.csv']));
writetable(result.familySummary,fullfile(outDir,[stem '_families.csv']));
fprintf('Saved direct RGB scan to %s\n',fullfile(outDir,[stem '.mat']));
end

function showResults(candidates,summary,bestLow,bestHigh,opts)
figure('Name','Direct RGB red ramp scan'); hold on;
ids=unique(candidates.familyID);
for id=ids'
    t=candidates(candidates.familyID==id,:); [x,o]=sort(t.redLevel);
    plot(x,t.measuredCdM2(o),'Color',[0.82 0.82 0.82]);
end
bestID=summary.familyID(1); t=candidates(candidates.familyID==bestID,:);
[x,o]=sort(t.redLevel); plot(x,t.measuredCdM2(o),'k-o','LineWidth',2,'MarkerSize',4);
yline(opts.targetLow,'--'); yline(opts.targetHigh,'--');
plot(bestLow.redLevel,bestLow.measuredCdM2,'go','MarkerFaceColor','g');
plot(bestHigh.redLevel,bestHigh.measuredCdM2,'ro','MarkerFaceColor','r');
xlabel('Red-channel level'); ylabel('Measured luminance (cd/m^2)');
title('Direct RGB red ramp families'); box off;
end

function p = enterC24RgbMode(p)
% Close the L48 task window and open a temporary native 8-bit RGB window.
try
    if isfield(p.draw, 'window') && ~isempty(p.draw.window) && ...
            Screen('WindowKind', p.draw.window) == 1
        Screen('Close', p.draw.window);
    end
catch
    Screen('CloseAll');
end
Datapixx('Open');
Datapixx('SetVideoMode', 0); % C24: straight 8-bit RGB passthrough
Datapixx('RegWrRd');
AssertOpenGL;
PsychImaging('PrepareConfiguration');
screenNumber = max(Screen('Screens'));
[p.draw.window, p.draw.screenRect] = PsychImaging('OpenWindow', ...
    screenNumber, [0 0 0]);
Screen('ColorRange', p.draw.window, 255);
LoadIdentityClut(p.draw.window);
p.draw.middleXY = [p.draw.screenRect(3) / 2, p.draw.screenRect(4) / 2];
Screen('FillRect', p.draw.window, [0 0 0]);
Screen('Flip', p.draw.window);
end

function p = restoreL48TaskMode(p)
% Recreate the normal SRS L48 dual-CLUT display after the RGB scan.
try
    if isfield(p.draw, 'window') && ~isempty(p.draw.window) && ...
            Screen('WindowKind', p.draw.window) == 1
        Screen('FillRect', p.draw.window, [0 0 0]);
        Screen('Flip', p.draw.window);
        Screen('Close', p.draw.window);
    end
catch
    Screen('CloseAll');
end
Datapixx('Open');
Datapixx('SetVideoMode', 0);
Datapixx('RegWrRd');
p = pds.initDataPixx(p);
p = pds.initAudio(p);
end

function abortIfEscape
[isDown,~,keyCode]=KbCheck;
if isDown && keyCode(KbName('ESCAPE')), error('Red RGB scan aborted by user.'); end
end

function safeCloseWaitbar(h)
if ~isempty(h) && ishandle(h), close(h); end
end
