% TERNLABEL label ternary phase diagram
%   TERNLABEL('ALABEL', 'BLABEL', 'CLABEL') labels a ternary phase diagram created using TERNPLOT
%   
%   H = TERNLABEL('ALABEL', 'BLABEL', 'CLABEL') returns handles to the text objects created.
%   with the labels provided.  TeX escape codes are accepted.
%
%   See also TERNPLOT

% Author: Carl Sandrock 20020827
% Modified: François Beauducel 20040318

function h = ternlabel(A, B, C, mode)

if nargin < 4
    mode = 1;
end

switch mode
case 1
    r(1) = text(0.35*sin(pi/6), 0.5, A, 'rotation', 60, 'horizontalalignment', 'center');
    r(2) = text(0.5, -0.1, B, 'horizontalalignment', 'center');
    r(3) = text(1-0.35*sin(pi/6), 0.5, C, 'rotation', -60, 'horizontalalignment', 'center');
otherwise
    r(1) = text(-0.1, -0.1, A, 'horizontalalignment', 'center', 'FontWeight', 'bold');
    r(2) = text(1.1, -0.1, B, 'horizontalalignment', 'center', 'FontWeight', 'bold');
    r(3) = text(0.5, 1, C, 'horizontalalignment', 'center', 'FontWeight', 'bold');
end

if nargout > 0
    h = r;
end;