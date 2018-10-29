function [sta,ratio]=music3c_staltaratio(ydat,fs,tsta,tlta)


npts=size(ydat,1);
ydat=detrend(ydat);
nsta=fs*tsta;
if tlta > 0; nlta=fs*tlta; end
sta=zeros(1,npts);
ratio=sta;
sta(1)=sqrt(sum(ydat(1:fix(nsta)).^2)/nsta);
lta0=2000*sta(1);
ratio(1)=1;
for ii=2:npts
    sta(ii)=(ydat(ii).^2 - sta(ii-1))/nsta + sta(ii-1);
    if tlta > 0
        lta=(ydat(ii).^2 - lta0)/nlta + lta0;
        lta0=lta;ratio(ii)=sta(ii)/lta;
    end
end
