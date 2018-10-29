function s=ll2dms(x,ll)
%LL2DMS Latitude or longitude in Degree, Minute, Seconds format
%       LL2DMS(X,'lat') or LL2DMS(X,'lon') returns a string dd°mm'ss"[N|S|E|W] 
%       from decimal latitude or longitude X, depending on the second argument.
%
%       (c) F. Beauducel, OVSG 2002.

if strcmp(lower(ll),'lat')
    if x < 0
        c = 'S';
    else
        c = 'N';
    end
else
    if x < 0
        c = 'W';
    else
        c = 'E';
    end
end

x = abs(x);
dd = fix(x);
mm = fix((x-dd)*60);
ss = round((x-dd-mm/60)*3600);

s = sprintf('%3d°%02d''%2d" %c',dd,mm,ss,c);
