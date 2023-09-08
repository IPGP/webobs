function y=isoctave
%isoctave returns 1 (true) if the environment is GNU Octave

if exist('OCTAVE_VERSION', 'builtin')
    y = true;
else
    y = false;
end
