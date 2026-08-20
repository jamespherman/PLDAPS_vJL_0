function folderPath = i1MexFolder()
%I1MEXFOLDER Absolute path to the directly callable i1Pro MEX in this repo.
%
% folderPath = pds.i1MexFolder()
%
% The i1 actions call the bare name I1(...), which MATLAB cannot resolve from
% inside the +pds package, so the MEX ships in externalTools/i1 instead. The
% location is derived from this file so the actions work from any clone on any
% machine.

folderPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'externalTools', 'i1');

end
