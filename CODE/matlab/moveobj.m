function hh=moveobj(h,v)
%MOVEOBJ Move object
%	HH=MOVEOBJ(H,V) moves the object(s) in handle H by translation vector
%	V=[DX,DY] or V=[DX,DY,DZ].
%
%	Author: F. Beauducel
%	Created: 2021-01-18 in Yogyakarta, Indonesia

xyz = [0,0,0];
if numel(v) == 3
	xyz = v;
elseif numel(v) > 0 && numel(v) < 3
	xyz(1:numel(v)) = v;
end

for n = 1:numel(h)
	switch get(h(n),'Type')
	case 'text'
		if any(xyz) ~= 0
			set(h(n),'Position',get(h(n),'Position')+xyz);
		end
	otherwise
		if xyz(1) ~= 0
			set(h(n),'XData',get(h(n),'XData')+xyz(1));
		end
		if xyz(2) ~= 0
			set(h(n),'YData',get(h(n),'YData')+xyz(2));
		end
		if xyz(3) ~= 0
			zdata = get(h(n),'ZData');
			if isempty(zdata)
				set(h(n),'ZData',xyz(3)*ones(size(get(h(n),'XData'))));
			else
				set(h(n),'ZData',zdata+xyz(3));
			end
		end
	end
end
