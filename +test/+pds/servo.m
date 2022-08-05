function result = servo(instr)
%   result = pds.servo(instr)
%
% Shamelessly stolen by lnk from J Cavanaugh and placed here in +pds. 
% We can use this to poll the location of the LSR drive.
% Note that it is relative to whatever you set as 0, so there is still a
% manual step here, which is to know (or write down) what 0 is relative
% some refernce.

	import java.io.*;
	import java.net.*;

    if nargin
        %# connect to server
        try
            sock = Socket('ikura.local',31313);
            in = BufferedReader(InputStreamReader(sock.getInputStream));
            out = PrintWriter(sock.getOutputStream,true);
        catch ME
            error(ME.identifier, 'Connection Error: %s', ME.message)
        end
        
        out.println(instr);
        
        %# get response from server
        result = in.readLine();
        
        %# cleanup
        out.close();
        in.close();
        sock.close();
    else
        disp(' ');
        disp(' ');
        disp('Available commands:')
        disp(' ');
        disp('  GETPOS:       get current depth in microns');
        disp('  SETPOSxxxx:   set current position to xxxx microns');
        disp('  SETHOME:      set current position as home position');
        disp('  GETHOME:      get home position');
        disp('  GOHOME:       move to home position');
        disp('  ZERO:         set current position as depth zero');
        disp('  MODECONT:     set wired remote mode to continuous movement');
        disp('  MODESTEP:     set wired remote mode to step movement');
        disp('  TOGGLEMODE:   toggle between step and continuous mode');
        disp('  SETSTEPxxxx:  set remote step size in microns');
        disp('  SETSPEEDxxxx: set movement speed in microns/s (min 100)');
        disp('  GETSPEED:     get movement speed in microns/s');
        disp('  SETACCELxxxx: set acceleration in microns/s/s');
        disp('  GETACCEL:     get acceleration');
        disp('  SETDECELxxxx: set deceleration in microns/s/s');
        disp('  GETDECEL:     get deceleration');
        disp('  STOP:         stop electrode movement');
        disp('  UPxxxx:       move up xxxx microns');
        disp('  DOWNxxxx:     move down xxxx mirons');
        disp('  GOTOxxxx:     move to depth xxxx');
        disp('  STATUS:       get status of server');
        disp('  ENABLE:       enable motor (prevents manual movement)');
        disp('  DISABLE:      disable motor (allows manual movement)');
        disp('  QUIT:         quit the server application');
        disp(' ');
    end;

