function A = structmerge(A,B,re)
%STRUCTMERGE Merging structures
%	A = STRUCTMERGE(A,B) merges fields of structure B in structure A,
%   overwriting existing fields if necessary, and returns a merged structure.
%
%   STRUCTMERGE(A,B,REGEX) will merge only field with names matching regular
%   expression REGEX.
%
%	Authors: F. Beauducel, WEBOBS/IPGP
%	Created: 2017-05-15 in Ternate, Indonesia
%	Updated: 2025-02-28

if nargin < 2 || ~isstruct(A) || ~isstruct(B)
	error('A and B arguments must be structures.')
end

for sf = fieldnames(B)'
    if nargin < 3 || ~isempty(regexp(sf{1},re))
        A.(sf{1}) = B.(sf{1});
    end
end

