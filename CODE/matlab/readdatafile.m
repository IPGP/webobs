function data = readdatafile(f,varargin)
%READDATAFILE Read data file.
%	READDATAFILE(F) imports data from pipe-separated file F, and returns a
%	cell array of strings.
%
%	READDATADFILE(F,NCOL) reads only NCOL columns and excludes lines with
%	lower number of columns.
%
%	READDATAFILE(...,'Param',value) adds any couple of parameters to the 
%	main textscan() function.
%
%	READDATAFILE ignores header line and any lines starting with '-'
%	(deleted data records).
%
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2013-12-29
%	Updated: 2015-06-12

if ~exist(f,'file')
	error('WEBOBS{readdatafile}: %s not found.',f);
end

ncol = 0;
opt = {'delimiter','\n'};
if ~any(strcmpi(varargin,'CommentStyle'))
	opt = [opt,{'CommentStyle','-'}];
end

if nargin > 1
	if isnumeric(varargin{1})
		ncol = varargin{1};
		if nargin > 2
			varargin = varargin(2:end);
		else
			varargin = {};
		end
	end
end

fprintf('WEBOBS{readdatafile}: reading %s ...',f);

% reads the entire file
fid = fopen(f);
	lines = textscan(fid, '%s', opt{:},varargin{:});
fclose(fid);

data = regexp(lines{1}(1:end), '\|', 'split');

% truncates to the specified number of columns (if needed)
if ncol > 0
	for n = 1:length(data)
		if length(data{n}) >= ncol
			data{n} = data{n}(1:ncol);
		end
	end
end

% file must have same number of columns to be concatanated... gives here some debugging information
try
	data = cat(1,data{:});
catch
	n = cellfun(@length,data);
	k = find(n~=median(n),1);
	fprintf('abort.\n*** Different number of columns: generally %d but line %d has %d ! ***\n',median(n),k,n(k));
	error('WEBOBS{readdatafile}: cannot import data file.');
end

fprintf(' imported  (%d rows x %d columns).\n',size(data));
