function data = readdatafile(f,filt)
%READDATAFILE Read data file.
%	READDATAFILE(F) imports data from pipe-separated file F, and returns a vector of
%	cell array of strings.
%
%	READDATAFILE ignores header line and any lines starting with '-' (deleted data records).
%
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2013-12-29

if ~exist(f,'file')
	error('WEBOBS{readdatafile}: %s not found.',f);
end

fprintf('WEBOBS{readdatafile}: reading %s ...',f);

fid = fopen(f);
% reads first line to determine the number of columns
data = textscan(fid,'%s',1,'Delimiter','\n');
h = split(data{1},'|');
n = length(h{:});
if ~strcmp(h{1},'ID')
	fseek(fid,0,-1);
end
data = textscan(fid,[repmat('%s',[1,n-1]),'%[^\n]'],'Delimiter','|','WhiteSpace','','CommentStyle','-');
fclose(fid);

fprintf(' imported  (%d rows x %d columns).\n',length(data{1}),n);
