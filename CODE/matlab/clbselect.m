function X=clbselect(X,s)
%CLBSELECT Calibration channel selection
%	Y=CLBSELECT(X,CHAN) selects channels CHAN in calibration structure X and
%	returns new calibration structure Y. CHAN can be either a cell array of
%	strings with channel names, or a vector of channel numbers, as given in
%	the node's calibration file.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2017-01-13 in Yogyakarta, Indonesia
%	Updated: 2022-07-25

if ischar(s)
	s = cellstr(s);
end

% replaces wildcards (? and *) by valid regexp
s = regexprep(s,'\?','.');
s = regexprep(s,'\*','.*');

% finds unvalid CHAN in C.cd list
k = [];
for n = 1:X.nx
	if all(cellfun(@isempty,regexp(X.cd(n),s)))
		k = cat(2,k,n);
	end
end

for fd = fieldnames(X)'
	if ~strcmp(fd,'nx')
		X.(fd{:})(k) = [];
	end
end
X.nx = length(unique(X.nv));
