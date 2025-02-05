document.onclick = function() {
    skn.visibility = "visible";
}
document.onmousemove = function() {
    document.getElementById('menu').style.visibility = 'visible';
}
window.onscroll = function() {
    document.getElementById('menu').style.visibility = 'hidden';
    skn.visibility = "hidden";
}

function active(menuid, pageid) {
    pass = 0;
    // Changement des couleurs de la barre de menu pour mettre en évidence le menu sélectionné
    while (pass < zlien[menuid].length) {
        // window.alert(document.getElementById('menu'+menuid+'_'+pass).className);
        if (pass == pageid) {
            document.getElementById('menu' + menuid + '_' + pass).className = document.getElementById('menu' + menuid + '_' + pass).className.indexOf('externe') > 0 ? 'menu bas externe actif' : 'menu bas actif';
        } else {
            // window.alert("pass="+pass+"menuid="+menuid+"pageid="+pageid);
            document.getElementById('menu' + menuid + '_' + pass).className = document.getElementById('menu' + menuid + '_' + pass).className.indexOf('externe') > 0 ? 'menu bas externe inactif' : 'menu bas inactif';
        }
        pass += 3;
    }
}

function pop(menuid, msg) {
    pass = 0;
    // Changement des couleurs de la barre de menu pour mettre en évidence le menu sélectionné
    while (pass < menu.length / 3) {
        if (pass == menuid) {
            document.getElementById('menu' + pass).className = "menu haut actif";
        } else {
            document.getElementById('menu' + pass).className = "menu haut inactif";
        }
        pass++;
    }
    skn.visibility = "hidden";
    if (msg.length == 0) return;
    pass = 0;
    content = "<table><tr>";
    while (pass < msg.length) {
        content += '<td id="menu' + menuid + '_' + pass + '" class="' + (msg[pass + 2] == '_blank' ? 'menu bas externe inactif' : 'menu bas inactif') + '" onMouseOver="active(' + menuid + ',' + pass + ')"><a href="' + msg[pass + 1] + '" target="' + msg[pass + 2] + '"><span>' + msg[pass] + '</span></a></td>\n';
        pass += 3;
    }
    content += "<" + "/tr>";
    document.getElementById("menu-bas").innerHTML = content;
    skn.visibility = "visible";
}

function aff_menu() {
    pass = 0;
    while (pass < menu.length / 3) {
        if (menu[pass * 3 + 1] == '') {
            document.write('<td id="menu' + pass + '" class="menu haut inactif" onMouseOver="pop(' + pass + ',zlien[' + pass + '])">' + menu[pass * 3] + '</td>');
        } else {
            document.write('<td id="menu' + pass + '" class="menu haut inactif" onMouseOver="pop(' + pass + ',zlien[' + pass + '])"><a href="' + menu[pass * 3 + 1] + '" target="' + menu[pass * 3 + 2] + '"><span>' + menu[pass * 3] + '</span></a></td>');
        }
        pass++;
    }
}
