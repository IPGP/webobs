 function [z,time]=rsac(ff,format)
%
% [s,time]=rsac(fichier,[format])
%

% LECTURE DE FICHIERS AU FORMAT SAC

if eq(format,'be')
   format = 'ieee-be';
else
   format = 'ieee-le';
end

% Ouverture du fichier
                fid1=fopen(ff,'r',format);
%                 fid1=fopen(ff,'r');

% Lecture 1 du header SAC (en float): lecture tau=pas d'echantillonnage
                h1=fread(fid1,70,'float');
                tau=h1(1);stick=h1(2);

% Lecture 2 du header SAC (en long): lecture date/heure 1er echantillon
                h2=fread(fid1,40,'long');
                fe=1/(2*tau);
                an0=h2(1);jr0=h2(2);hr0=h2(3);mn0=h2(4);sec0=h2(5)+h2(6)/1000;

% Lecture 2 du header SAC (en char): lecture date/heure 1er echantillon
                h3=fread(fid1,192,'uchar');

%%%%  Lecture des donnees dans tableau z
                z=fread(fid1,inf,'float');

                fclose(fid1);
%
time=((1:length(z))-1)*tau;