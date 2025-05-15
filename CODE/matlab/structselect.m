function B = structselect(A,re)
%STRUCTSELECT Select fields in a structure
%	B = STRUCTSELECT(A,REGEX) selects fields in structure A where fieldname matches
%   regular expression REGEX, and returns structure B.
%
%	Authors: F. Beauducel, WEBOBS/IPGP 
%	Created: 2025-02-27
%	Updated: 2025-02-28


B = struct;
fn = fieldnames(A);
for k = 1:length(fn)
    if ~isempty(regexp(fn{k},re))
        B.(fn{k}) = A.(fn{k});
    end
end
