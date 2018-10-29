function cx=exbln(c,xlim,ylim);
%EXBLN Extract BLN contour lines.
%       CX=EXBLN(C,XLIM,YLIM) extracts contour lines in C which 
%       coordinates are included between XLIM=[XMIN,XMAX] and YLIM=[XMIN,XMAX]
%       and returns a new contour lines matric CX.
%
%       (c) F. Beauducel, OVSG-IPGP, 2004

cx = [];
i = 1;
while i > 0
    k = (i+1):(i+c(2,i));
    kk = find(c(1,k) >= xlim(1) & c(1,k) <= xlim(2) & c(2,k) >= ylim(1) & c(2,k) <= ylim(2));
    if ~isempty(kk)
        cx = [cx,[c(1,i);length(kk)],c(:,k(kk))];
    end
    i = i + c(2,i) + 1;
    if i >= size(c,2)
        i = -1;
    end
end
