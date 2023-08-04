function p = transferEdfFile(p)
% Function for transferring copy of EDF file to the experiment folder on Display PC.
% Allows for optional destination path which is different from experiment folder
% 

try
    if p.init.elDummyMode == 0 % If connected to EyeLink

        % Show 'Receiving data file...' text until file transfer is complete
        Screen('FillRect', p.draw.window, p.init.el.backgroundcolour); % Prepare background on backbuffer
        Screen('DrawText', p.draw.window, 'Receiving data file...', 5, p.draw.screenRect(end)-35, 0); % Prepare text
        Screen('Flip', p.draw.window); % Present text
        fprintf('Receiving data file ''%s.edf''\n', p.init.edfFile); % Print some text in Matlab's Command Window

        % Transfer EDF file to "output" directory of PLDAPS
        status = Eyelink('ReceiveFile', p.init.edfFile, p.init.outputFolder, 1);

        % Optionally uncomment below to change edf file name when a copy is transferred to the Display PC
        % % If <src> is omitted, tracker will send last opened data file.
        % % If <dest> is omitted, creates local file with source file name.
        % % Else, creates file using <dest> as name.  If <dest_is_path> is supplied and non-zero
        % % uses source file name but adds <dest> as directory path.
        % newName = ['Test_',char(datetime('now','TimeZone','local','Format','y_M_d_HH_mm')),'.edf'];
        % status = Eyelink('ReceiveFile', [], newName, 0);

        % Check if EDF file has been transferred successfully and print file size in Matlab's Command Window
        if status > 0
            fprintf('EDF file size: %.1f KB\n', status/1024); % Divide file size by 1024 to convert bytes to KB
        end
        % Print transferred EDF file path in Matlab's Command Window
        fprintf('Data file ''%s.edf'' can be found in ''%s''\n', p.init.edfFile, pwd);
    else
        fprintf('No EDF file saved in Dummy mode\n');
    end
catch % Catch a file-transfer error and print some text in Matlab's Command Window
    fprintf('Problem receiving data file ''%s''\n', p.init.edfFile);
    psychrethrow(psychlasterror);
end
end