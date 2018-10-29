function [xnslow,fid,h7]=music3c_discriminator311(td,BarreErr, exsignal ,result)

fid=0;
 
 xtt1=result(:,1);
 xff=result(:,2);
 xthe=result(:,3);
 xtherr=result(:,4);
 xvel=result(:,7);
 xvelerr=result(:,8);
 xphi=result(:,5);
 xphierr=result(:,6);
 xvelp=result(:,9);
 xvelperr=result(:,10);

 xtt0=exsignal(:,1);
 xmerapi= exsignal(:,2);


xi = linspace(min(xtt0),max(xtt0),0.2*numel(xtt0))';
yi = interp1(xtt0,xmerapi,xi,'spline');

kk=1;mm=1;thcorr=0;  

if exist ('BarreErr')
else BarreErr = 0;
end

for ii=1:length(xtt1)
     
            ntt(kk)=xtt1(ii);
            nff(kk)=xff(ii);
            nazm(kk)=xthe(ii)+thcorr;
            nazmerr(kk)=xtherr(ii);
            nvel(kk)=xvel(ii);
            nvelerr(kk)=xvelerr(ii);
            nphi(kk)=xphi(ii);
            nphierr(kk)=xphierr(ii);
            nvelp(kk)=xvelp(ii);
            nvelperr(kk)=xvelperr(ii);
            nphiv(kk)=asind(nvelp(kk)/nvel(kk));
            if ~isreal(nphiv(kk));nphiv(kk)=asind(nvel(kk)/nvelp(kk));end
            if nphiv(kk) > 89 && xphi(ii) < 104 && xphi(ii) > 89
                nphiv(kk)= xphi(ii);
            end
            nphiv(kk)= nphiv(kk); %merapi slope;
            kk=kk+1;
       
   
    
end
ntt=ntt+td;

xnslow={ntt,nff,nazm,nazmerr,nvel,nvelerr,nphiv,nphierr,nvelp,nvelperr};


h7=cfigure(24,19);

%titre=char(strcat({'Résultats obtenus par Music3c pour les signaux  '},{nomdate}));
sp(1)=subplot(5,1,1);plot(yi/1000); 
ylabel('Signal'); xlim([0 length(xi)]);

sp(2)=subplot(5,1,2);xlim([0 200]);plot(ntt,xff,'r.'); ylabel('freq des pics'); axis tight ;xlim([0 length(xtt0)/100]);

sp(3)=subplot(5,1,3);
colormap(jet(10));
colormap(hsv)
if BarreErr == 1
h=errorbar(ntt,nazm,nazmerr,'.');
hold on
scatter(ntt,nazm,11,xff,'filled')
hold off
else 
    scatter(ntt,nazm,11,xff,'filled')
end
colorbar('east')
ylim([0 360]);ylabel('AZM');hold on;
line(xtt0,180,'LineStyle','--','Color',[.8 .8 .8]);
set(gca,'ylim',[0 360],'ytick',0:60:360);
xlim([0 length(xtt0)/100]);

sp(4)=subplot(5,1,4);
if BarreErr == 1
errorbar(ntt,nphiv,nphierr,'.')
hold on
scatter(ntt,nphiv,11,xff,'filled')
hold off
else 
    scatter(ntt,nphiv,11,xff,'filled')
end    
colorbar('east');;
set(gca,'ylim',[0 180],'ytick',0:30:180);
xlim([0 length(xtt0)/100]);

ylim([0 150]);ylabel('INC');hold on;
line(xtt0,90,'LineStyle','-','Color',[.8 .8 .8]);
xlim([0 length(xtt0)/100]);


sp(5)=subplot(5,1,5);
if BarreErr == 1
errorbar(ntt,nvelp,nvelperr,'.')
hold on
scatter(ntt,nvelp,11,xff,'filled')
hold off
else 
    scatter(ntt,nvelp,11,xff,'filled')
end
colorbar('east');
set(gca,'ylim',[0 5000],'ytick',0:1000:5000);
xlim([0 length(xtt0)/100]);


ylim([100 5000]);ylabel('Vel Ap'); xlim([0 length(xtt0)/100]);


