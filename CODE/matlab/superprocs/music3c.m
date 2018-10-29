function DOUT=music3c(varargin)

WO = readcfg;

% --- checks input arguments
if nargin < 1
	error('WEBOBS{genplot}: must define PROC name.');
end

proc = varargin{1};				

% starts process
timelog(proc,1);				% log classique, affiche date et heure à l’écran

% gets PROC's configuration, associated nodes for any TSCALE and/or REQDIR and the data
[P,N,D] = readproc(WO,varargin{:});		% P = paramètres de la PROC (donc du programme)
						% N = noeud associés à la proc (association entre la proc et les stations)
						% D = données (4 dimensions)


%% Creation des parametres
params(1)= str2double(P.WINLENGTH_S);             %taille de la fenetre glissante (en s)
params(2)= str2double(P.TIMEKEEP_S);              %chevauchement entre 2 fenetres (en s)
params(3)= str2double(P.NFFT);                    %Parametre de la fft
params(4)= str2double(P.THRESHOLD_FFT);            %Seuil de detection des pics du spectre normalis� 
params(5)= str2double(P.NSHOTS);                  %Nombres d'echantillons a analyser autour du pic de frequence repere
params(6)= str2double(P.FMAX_HZ);                 %Frequence maximale du spectre a passer au detecteur de pics (en Hz)
params(7)= str2double(P.FLIM_PICS_HZ);            %Condition d'affichage du vecteur lenteur sur la frequence du pic selectionn� 
fs= str2double(P.FS_HZ);                          %Frequence d'echantil


%% Importation donn�es
B=length(N);

matlong=zeros(1,B);
 for j = 1:B
    matlong(j)=length(D(j).t);
 end
 
[longmax , g]=max(matlong);

windowstart =1 ; %155500;
windowend   =length(D(g).t) ; %157500; 
 
xdata1=NaN(longmax,B);
ydata1=NaN(longmax,B);
zdata1=NaN(longmax,B);

 for n= 1: B
   if ~all(isnan(D(n).t)) 
    D1(n).d(:,1)=interp1(D(n).t,D(n).d(:,1),D(g).t);
    D1(n).d(:,2)=interp1(D(n).t,D(n).d(:,2),D(g).t);
    D1(n).d(:,3)=interp1(D(n).t,D(n).d(:,3),D(g).t);
   end
 end


for j= 1:B
    if ~all(isnan(D(j).t)) 
    xdata1(1:length(D(j).t),j)= D1(j).d(1:length(D(j).t),1);
    ydata1(1:length(D(j).t),j)= D1(j).d(1:length(D(j).t),2);
    zdata1(1:length(D(j).t),j)= D1(j).d(1:length(D(j).t),3);
    end
end



%% Fenetre du signal a analyser 

xdata1=xdata1(windowstart:windowend,:);
ydata1=ydata1(windowstart:windowend,:);
zdata1=zdata1(windowstart:windowend,:);

%% filtre

%Limites de la bande:

bpf=str2num(P.BANDPASS_FILTER_HZ);
f1=min(bpf);
f2=max(bpf);

%[B,A] = butter(1,[f1 f2]/fs);
%xdata = filter(B,A,xdata1);
%ydata = filter(B,A,ydata1);
%zdata = filter(B,A,zdata1);



%% creation matrice coord des stations
MatPosiStat=[ll2utm(cat(1,N.LAT_WGS84) ,cat(1, N.LON_WGS84)) , cat(1,N.ALTITUDE)];

merapipos=MatPosiStat - repmat(MatPosiStat(1,:),size(MatPosiStat,1),1);


%% Calcul Vecteur lecteur

[nforce,ff , result]=music3c_merapiwinmusic(xdata1,ydata1,zdata1,merapipos,fs,params,f1,f2);


%% redaction fichier sortie
if ~isempty(result)
	tdeb = D(g).t(1) + (result(1,1)+ windowstart/fs)/86400;
	rep = sprintf('%s/%s/%s',P.OUTDIR,WO.PATH_OUTG_EXPORT,datestr(tdeb,'yyyy/mm/dd'));
	mkdir(rep);
	nomfichier = sprintf('%s/resultMUSIC3C_%s',rep,datestr(tdeb,'yyyymmdd_HHMM'));
	fid=fopen([nomfichier '.log'],'wt');
	fprintf(fid,'%4d %02d %02d  %2d %2d %5.2f      %3.1f     %5.1f    %5.1f    %5.1f   %5.1f     %7.1f   %7.1f   %7.1f   %7.1f\n',[datevec(D(g).t(1) + (result(:,1)+ windowstart/fs)/(24*60*60)),result(:,2:10)]');
	fclose(fid);
else
	disp('no results');
end





if P.REQUEST
	mkendreq(WO,P);						% si requête manuelle (mode request)
end

timelog(proc,2)


% Returns data in DOUT
if nargout > 0
	DOUT = D;
end

