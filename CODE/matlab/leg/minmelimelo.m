function s = minmelimelo(r)

global dm

m = melimelo(r);
%s = sum((m(:) - dm(:)).^2);
s = m(:) - dm(:);
