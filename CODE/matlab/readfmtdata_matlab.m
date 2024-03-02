function D = readfmtdata_matlab(WO,P,N,F)
%READFMTDATA_MATLAB subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: Matlab file
%	output fields:
%		D.t (datenum)
%		D.d (data1 data2 ...)
%
%	format 'mat-file'
%		type: Matlab MAT-file
%		RAWDATA: full path filename
%		data format: workspace with 't' time vector (datenum), 'd' data matrix,
%	 	   and optional e error matrix
%		FIDs: optional FID_T, FID_D, and FID_E to set the variable names
%		node calibration: possible use of the channel code to order channels
%
%
%	Authors: François Beauducel, WEBOBS/IPGP
%	Created: 2017-10-14 in Bali, Indonesia
%	Updated: 2024-02-29

wofun = sprintf('WEBOBS{%s}',mfilename);


fdat = F.raw{1};

t = [];
d = [];
e = [];

V.t = field2str(N,'FID_T','t','notempty');
V.d = field2str(N,'FID_D','d','notempty');
V.e = field2str(N,'FID_E','e','notempty');

% --- loads the file
if exist(fdat,'file')
	var = who('-file',fdat); % list of available variables
	for v = {'t','d','e'}
		vv = v{:};
		s = regexprep(V.(vv),'[.({].*','');
		if ismember(s,var)
			load(fdat,'-mat',s);
			if ~strcmp(s,vv)
				eval(sprintf('%s = %s;',vv,V.(vv)));
			end
		else
			fprintf('** WARNING ** no "%s" matrix found in the MAT-file (looking for "%s")...\n',s,vv);
		end
	end

end

if ~isempty(t) && size(d,1) == size(t,1)
	fprintf(' done (%d x %d samples).\n',size(d));
	if exist('e','var') && any(size(d) ~= size(e))
		fprintf('** WARNING ** "e" matrix size (%d x %d samples) does not match "d". Hope it''s OK for the proc...\n',size(e));
	end
else
	fprintf('** WARNING ** no available data found!\n');
end

D.t = t - N.UTC_DATA;
D.d = d;
D.e = e;
[D.d,D.CLB] = calib(D.t,D.d,N.CLB,'channelcodeorder');
D.t = D.t + P.TZ/24;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function s = mainvar(v)
% reduces variable name