function rc = notify(WO,evt,sid,msg)
%NOTIFY Notify to the WebObs PostBoard
%       NOTIFY(WO,event-name,sender-id,message) the matlab version of the 
%       perl's WebObs::Config::notify function.
%
%       NOTIFY will send 'timestamp|event-name|sender-id|message' to 
%       WO.POSTBOARD_NPIPE npipe file.
%
%       Assumes that arguments do NOT contain any \n characters !
%
%   Authors: D. Lafon, F. Beauducel, WEBOBS/IPGP
%   Created: 2014-04-25
%   Updated: 2017-08-02


if nargin == 4
	if isfield(WO,'POSTBOARD_NPIPE') && ~isempty(WO.POSTBOARD_NPIPE)
		if exist(WO.POSTBOARD_NPIPE,'file')
			fid = fopen(WO.POSTBOARD_NPIPE,'w');
			if fid ~= -1
				ts = floor((now-datenum(1970,1,1))*86400);
				fprintf(fid,'%d|%s|%s|%s\n',ts,evt,sid,msg);
				fclose(fid);
				rc = 0;
				fprintf('WEBOBS{notify}: message sent to postboard event "%s".\n',evt);
			else
				rc = 96; % can't open fifo
			end
		else
			rc = 99; % input msg has invalid format
		end
	else
		rc = 98; % fifo is not defined
	end	
else
	rc = 97; % nothing to send
end

