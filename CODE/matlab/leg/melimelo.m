function m = melimelo(r)

m = zeros(2,8);
r = flipud(reshape(flipud(r(:)),[2,8])')';
rr = sum(r);
i0 = 1:8;

for i = 1:size(m,1)
    for j = 1:size(m,2)
        ii = i0;
        ii(j) = [];
        m(i,j) = 1/(1/r(i,j) + 1/(r(mod(i,2)+1,j) + 1/sum(1./rr(ii))));
    end
end
