function displayTrialStatus(p)
%DISPLAYTRIALSTATUS Display current block and trial information cleanly.

fprintf('\n');
fprintf('============================================================\n');
fprintf('           TASK STATUS SUMMARY                              \n');
printField('            Good Trial ',p.status.iGoodTrial);
fprintf('============================================================\n');

fprintf('\n');
fprintf('------------------------- BLOCK ----------------------------\n');


if p.status.CurrentBlockType == 1, blocktype = 'T1 Rich' ;
else,    blocktype = 'T2 Rich'; end
if p.status.CurrentTrialType == 1, trialtype = 'Congruent' ;
else,    trialtype = 'Conflict'; end

printField('Current block type',      blocktype);
printField('Current block number',    p.status.CurrentBlockNumber);
printField('Remaining blocks',        p.status.RemainingBlock);

fprintf('\n');
fprintf('---------------------- BLOCK CONTENT -----------------------\n');
printField('Total trials per block',  p.status.TotalTrialsPerBlock);
printField('Current trial type',      trialtype);
printField('Remaining conflict',      p.status.RemainingConflict);
printField('Remaining congruent',     p.status.RemainingCongruent);

fprintf('\n');
fprintf('-------------------------- TRIAL ---------------------------\n');
printField('Actual trial type',       p.status.ActualTrialType);
printField('Actual rich reward',      p.status.ActualRichReward);
printField('Actual poor reward',      p.status.ActualPoorReward);

fprintf('============================================================\n');
fprintf('\n');

end


function printField(label, value)
%PRINTFIELD Print one aligned label-value pair.

fprintf('  %-28s : %s\n', label, valueToString(value));

end


function txt = valueToString(value)
%VALUETOSTRING Convert different MATLAB value types into readable text.

if ischar(value)
    txt = value;

elseif isstring(value)
    txt = char(value);

elseif isnumeric(value)
    if isscalar(value)
        txt = num2str(value);
    else
        txt = mat2str(value);
    end

elseif islogical(value)
    if value
        txt = 'true';
    else
        txt = 'false';
    end

elseif iscategorical(value)
    txt = char(value);

else
    txt = '<unsupported type>';
end

end


