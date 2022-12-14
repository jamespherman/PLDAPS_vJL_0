function p               = extraWindowSetup(p)

% if we're using the mapping gui, initialize it here
if p.trVarsInit.setTargLocViaGui
    
    % first check to see if there's already a gui open and close it.
    guiHandle = findall(0, 'Name', 'saccade mapping GUI');
    if ~isempty(guiHandle)
        close(guiHandle)
    end
    
    % open new gui window
    p.init.guiData = saccadeGUI(false);
    
    % reposition saccade gui window relative to main gui window
    mainGuiPos = get(findall(0, 'Name', 'PLDAPS_vK2_GUI'), 'Position');
    set(p.init.guiData.handles.hGui, 'Position', ...
        [sum([mainGuiPos([1 3]), 10]), mainGuiPos(2), 1500, 1200]);
end

end