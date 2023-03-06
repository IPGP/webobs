function y=isoctave
%isoctave returns 1 (true) if the environment is GNU Octave

V = ver;
if isstruct(V) && isfield(V,'Name')
    y = strcmpi(V(1).Name,'Octave');
else
    y = false;
end
