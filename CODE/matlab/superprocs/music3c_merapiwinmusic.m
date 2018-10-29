function [nforce,ff , result]= music3c_merapiwinmusic(nxdata,nydata,nzdata,npos,fs,params,f1,f2)


%params=[winsize timekeep nfft thresholdFFT nshots fs fmax]
%params=[3 2.95 16384 .8 20 fmax];wind-len,reused wind-len,NFFT,thres-peak,bins


% Filtre des pics :
limiteaffichage = params(7);

fprintf('Seuls les pics supérieurs a %g sont traités\n',limiteaffichage);

if (exist('params','var')~=1);params=[3 2.85 16384 .85 20 7];end
rec=1;t0=0;
nfft=params(3);pthrsh=params(4);nshots=params(5);
npts=size(nxdata,1);nlen=size(nxdata,2);
fflim1=params(6);
tt=(0:npts-1)/fs+t0;



ntheta=100;nphi=100;nvel=100;
theta=linspace(0,2*pi,ntheta);phi=linspace(0,pi,nphi);vel=linspace(10,15010,nvel);
stering={theta,phi,vel};
npp=1;kp=180/pi;
steps=round((params(1)-params(2))*fs);winlen=round(params(1)*fs);
wins=round((npts(1)-params(1)*fs)/steps);
ini=1:steps:round((npts(1)-params(1)*fs));
ff=fs*(0:nfft-1)/nfft;nff=fix(nfft*fflim1/fs);ff=ff(1:nff);

avancement = 1;
result=[];
for kk=1:wins
    
    % Debut suppression de l'offset et multiplication par une fonction de hamming (de chaque petite fenetre)
D =size(nxdata,2);
C=winlen+1;

nxfen1=zeros(winlen+1,D);
nyfen1=zeros(winlen+1,D);
nzfen1=zeros(winlen+1,D);

for j = 1:D
    nxfen1(:,j)=nxdata(ini(kk):ini(kk)+winlen,j)-polyval(polyfit(1:C,nxdata(ini(kk):ini(kk)+winlen,j)',1),1:C)';
    nyfen1(:,j)=nydata(ini(kk):ini(kk)+winlen,j)-polyval(polyfit(1:C,nydata(ini(kk):ini(kk)+winlen,j)',1),1:C)';
    nzfen1(:,j)=nzdata(ini(kk):ini(kk)+winlen,j)-polyval(polyfit(1:C,nzdata(ini(kk):ini(kk)+winlen,j)',1),1:C)';
end

[B,A] = butter(1,[f1 f2]/fs);
nxfen = filter(B,A,nxfen1);
nyfen = filter(B,A,nxfen1);
nzfen = filter(B,A,nxfen1);

nxfen = transpose(transpose(nxfen(:,:))*diag(hamming(C)));
nyfen = transpose(transpose(nyfen(:,:))*diag(hamming(C)));
nzfen = transpose(transpose(nzfen(:,:))*diag(hamming(C)));


    % Fin TS
    
    
    nxfft=fft(nxfen(:,:),nfft);nxfft=nxfft(1:nff,:);
    nyfft=fft(nyfen(:,:),nfft);nyfft=nyfft(1:nff,:);
    nzfft=fft(nzfen(:,:),nfft);nzfft=nzfft(1:nff,:);
    
    nxfftt=rsum(nxfft.');
    nyfftt=rsum(nyfft.');
    nzfftt=rsum(nzfft.');
    
    nforce=abs(nxfftt)+abs(nyfftt)+abs(nzfftt);


    
    [a,b,npidx]=music3c_peakdet7(nforce,ff,pthrsh);  
 
    StationBug3 = find(sum(isnan(nzfen)));
    nspecx=zeros(nlen-length(StationBug3));


    for mm=1:length(npidx)
        
        if npidx(mm)-nshots > 0
            
            nxsample=nxfft(npidx(mm)-nshots:npidx(mm)+nshots,:).';
            nysample=nyfft(npidx(mm)-nshots:npidx(mm)+nshots,:).';
            nzsample=nzfft(npidx(mm)-nshots:npidx(mm)+nshots,:).';
            
            
          %supp des NaA du spectre
           StationBug2 = find(isnan(nxsample(:,1)'));
                 for i = sort(StationBug2,'descend')
                     nxsample(i,:)=[];
                     nysample(i,:)=[];
                     nzsample(i,:)=[];
                 end 

               
            for nn=1:2*nshots+1
                nspecx=nspecx+(nxsample(:,nn)*nxsample(:,nn)'+nysample(:,nn)*nysample(:,nn)'+nzsample(:,nn)*nzsample(:,nn)')/(2*nshots+1);
            end

         
             
             if all([ff(npidx(mm))> limiteaffichage  , length(nspecx)>2] )
                
                 %def d'une nouvelle matrice npos en fonction du nombre de stations
                 nposactive=npos(all(~isnan(nxfen)),:);
%                  StationBug = find(sum(isnan(nxfen)));
%                  for i = sort(StationBug,'descend')
%                      nposactive(i,:)=[];
%                  end 

       
                [mtheta,mthetaerr,mvel,mvelerr,mphi,mphierr,mvelp,mvelperr]=music3c_merapmusic(nspecx,ff(npidx(mm)),nposactive,stering,0);
            for nn=1:length(mtheta)
                fprintf('%d/%d Merapi tt=%.2f fo=%.1f  azm=%.1f inc=%.1f  vel=%.1f  velp=%.1f\n',kk,wins,tt(ini(kk)),ff(npidx(mm)),mtheta(nn)*kp,mphi(nn)*kp,mvel(nn),mvelp(nn));
               
               
               result(avancement,:) = [tt(ini(kk)),ff(npidx(mm)),mtheta(nn)*kp,mthetaerr(nn)*kp,mphi(nn)*kp,mphierr(nn)*kp,mvel(nn),mvelerr(nn),mvelp(nn),mvelperr(nn)];
               avancement=avancement+1;   
                
            end
             end
             
            npp=npp+1;
        end
    end
   
    
end
if rec==1;end
