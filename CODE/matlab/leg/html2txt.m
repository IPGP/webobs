function txt=html2txt(f,ext1,ext2);
%HTML2TXT Convertit un fichier HTML en texte.
%       HTML2TXT(FILENAME) lit le fichier FILENAME au format HTML et renvoie une 
%       cellule de texte simple sans format ni code.
%
%       HTML2TXT(FILENAME,TAB) renvoie le code HTML complet contenu dans la cellule
%       de tableau immadiatement après la cellule TAB.
%
%       HTML2TXT(FILENAME,EXT1,EXT2) ne renvoie que la partie texte comprise entre
%       les chaines EXT1 et EXT2 exclues (lignes complètes).

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-12-31
%   Mise à jour : 2004-06-21

% Définition des équivalences
seq = {'&nbsp;',' ';'&quot;','"';'</td>',' ';'</p>',' ';'</tr>',' ';'<br>',' '};

s = textread(f,'%s','delimiter','\n','whitespace','');

ii = 1; ss = '';
for i = 1:length(s)
    t = s{i};
    for j = 1:length(seq)
        t = strrep(t,seq{j,1},seq{j,2});
        t = strrep(t,upper(seq{j,1}),seq{j,2});
    end
    k0 = findstr(t,'<');
    k1 = findstr(t,'>');
    dk = length(k1) - length(k0);
    if dk < 0
        k1 = [k1,length(t)];
    end
    if dk > 0
        k0 = [1,k0];
    end
    %if dk == 0
        eval(['t([' sprintf('%d:%d ',[k0;k1]) ']) = [];']);
    %end
    if ~isempty(t) & ~all(t==' ')
        txt{ii} = t;
        ii = ii + 1;
    end
end
if nargin == 3
    k1 = strmatch(ext1,txt);
    if isempty(k1)
        k1 = 0;
    else
        k1 = k1(1) + 1;
    end
    k2 = strmatch(ext2,txt);
    if isempty(k2)
        k2 = 0;
    else
        k2 = k2(end) - 1;
    end
    if k1 & k2
        txt = txt(k1:k2);
    else
        txt = '';
    end
end    

if nargin == 2
    for i = 1:length(txt)
        ss = sprintf('%s %s',ss,deblank(txt{i}));
    end
    txt = ss;
end
