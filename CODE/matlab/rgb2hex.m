function hex=rgb2hex(x)
%RGB2HEX Convert RGB to hexadecimal string
%
%    Author: F. Beauducel / WebObs
%   Created: 2022-06-12, in Saint-Pierre, La Réunion

if size(x,2) ~= 3 || min(x(:)) < 0 || max(x(:)) > 1
    error('Input must be a valid RGB 3-column matrix.');
end

hex = cell(size(x,1),1);
for n = 1:size(x,1)
    hex{n} = ['#' reshape(dec2hex(round(x(n,:)*255),2)',1,[])];
end
