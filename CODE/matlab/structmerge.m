function A = structmerge(A,B)
%STRUCTMERGE Merging structures
%	A = STRUCTMERGE(A,B) merges fields of structure A with fields in structure B,
%	overwriting existing fields if necessary, and returns a merged structure.
%
%	Authors: F. Beauducel, WEBOBS/IPGP
%	Created: 2017-05-15 in Ternate, Indonesia

if nargin < 2 || ~isstruct(A) || ~isstruct(B)
	error('A and B arguments must be structures.')
end

for sf = fieldnames(B)';
	A.(sf{:}) = B.(sf{:});
end

