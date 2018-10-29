function A = structcat(A,B)
%STRUCTCAT Concatenate structures
%	A = STRUCTCAT(A,B) concatenates structure B to structure A, after check of
%	fields in A and B.
%
%	Authors: F. Beauducel, WEBOBS/IPGP 
%	Created: 2013-02-23


ka = fieldnames(A);
kb = fieldnames(B);

% complete missing fields in B
d = setdiff(ka,kb);
if ~isempty(d)
	for i = 1:length(d)
		B.(d{i}) = '';
	end
end
kb = fieldnames(B);

% complete missing fields in A
d = setdiff(kb,ka);
if ~isempty(d)
	for i = 1:length(d)
		for j = 1:length(A)
			A(j).(d{i}) = '';
		end
	end
end

B = orderfields(B,A);
A(end+1) = B;

