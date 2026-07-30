function p = restoreCorrectionTrialSnapshot(p)
%RESTORECORRECTIONTRIALSNAPSHOT Restore exact reward/salience values.

if ~isfield(p.status, 'correctionTrialSnapshotValid') || ...
        ~p.status.correctionTrialSnapshotValid || ...
        ~isfield(p.status, 'correctionTrialSnapshot') || ...
        ~isstruct(p.status.correctionTrialSnapshot)
    error('Active correction trial has no valid saved condition snapshot.');
end

snapshot = p.status.correctionTrialSnapshot;
if isfield(snapshot, 'trVars') && isstruct(snapshot.trVars)
    names = fieldnames(snapshot.trVars);
    for i = 1:numel(names)
        p.trVars.(names{i}) = snapshot.trVars.(names{i});
    end
end

if isfield(snapshot, 'status') && isstruct(snapshot.status)
    names = fieldnames(snapshot.status);
    for i = 1:numel(names)
        p.status.(names{i}) = snapshot.status.(names{i});
    end
end

if isfield(snapshot, 'clut') && isstruct(snapshot.clut)
    p.draw.clut = snapshot.clut;
end

p.trVars.correctionSnapshotValid = 1;

end
