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
%		data format: workspace with t vector (datenum) and d matrix
%		node calibration: possible use of the channel code to order channels
%
%
%	Authors: François Beauducel, WEBOBS/IPGP
%	Created: 2017-10-14 in Bali, Indonesia
%	Updated: 2017-10-14

wofun = sprintf('WEBOBS{%s}',mfilename);


fdat = F.raw{1};


switch F.fmt

% -----------------------------------------------------------------------------
case 'mat-file'
	if exist(fdat,'file') 
		load(fdat,'-mat','t','d');
	else
		t = [];
		d = [];
	end

end

if ~isempty(t) && size(d,1) == size(t,1)
	fprintf(' done (%d x %d samples).\n',size(d));
else
	fprintf('** WARNING ** no available data found!\n');
end

D.t = t - N.UTC_DATA;
D.d = d;
[D.d,D.CLB] = calib(D.t,D.d,N.CLB,'channelcodeorder');
D.t = D.t + P.TZ/24;
