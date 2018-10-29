function text = readtextfile(f,varargin)
%READTEXTFILE Read text file.
%	READTEXTFILE(F) imports lines from text file F, and returns a
%	cell array of strings (one per line).
%
%	READTEXTFILE(...,'Param',value) adds any couple of parameters to the 
%	main textscan() function.
%
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2015-04-04
%	Updated: 2015-04-04

if ~exist(f,'file')
	error('WEBOBS{readtextfile}: %s not found.',f);
end

fprintf('WEBOBS{readdatafile}: reading %s ...',f);

% reads the entire file
fid = fopen(f);
	text = textscan(fid, '%s', 'delimiter', '\n',varargin{:});
fclose(fid);

text = text{1};

fprintf(' imported  (%d lines).\n',length(text));
