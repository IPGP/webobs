function rgb=html2rgb(x);
%HTML2RGB HTML to RGB color convertion.
%	HTML2RGB(X) returns 3-column RGB value(s) from HTML hexadecimal
%	color string.

%	Author: F. Beauducel, IPGP
%	Date: 2008-11-10

x = cellstr(x);
rgb = zeros(size(x,1),3);
for i = 1:size(x,1)
	rgb(i,:) = [hex2dec(x{i}(1:2)),hex2dec(x{i}(3:4)),hex2dec(x{i}(5:6))]/255;
end

