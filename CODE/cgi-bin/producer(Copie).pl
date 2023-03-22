<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="UTF-8">
    <title>Titre de la page</title>
    <script src="/js/jquery.js"></script>
  </head>
  <body>
    <p>Formulaire de renseignement du producteur de données</p>
    
    <form action="../cgi-bin/producer.pl" method="get" id="producer">
        <fieldset>
            <fieldset id='mandatory'>
                <legend>Champs obligatoires</legend>
                    <p><label>Identifiant: <input type="text" name="Identifier" value="OBSE"></label></p>
                    <p><label>Nom: <input type="text" name="Name" value="OBSERA"></p>
                    <p><label>Titre: <input type="text" name="Title" value="Observatoire de l'Eau et de l'Erosion aux Antilles"></p>
                    <p><label>Description: <textarea name="Description"></textarea></p>
                    <p><label>Courriel: <input type="text" name="Email"></p>
                    <p><label>Contacts: </label>&nbsp<button id="mgr" class="add">Ajouter un responsable des données</button></p>
                    <p>&nbspChef de projet: <input type="text" name="projectLeader"><p>
                    <div id="new_chq_mgr"></div>
                    <p><label>Financeurs: </label>&nbsp<button id="fund" class="add">Ajouter un financeur</button></p>
                    <p>&nbspType:
                        <select name="type" id="type">
                            <option value="FrenchResearchInstitutes">Institut de recherche français</option>
                            <option value="FederativeStructure">Structure fédérative</option>
                            <option value="ResearchUnit">Unité de recherche</option>
                            <option value="Other">Autre</option>
                            <option value="OtherUniversitiesAndSchools">Autres universités et écoles</option>
                            <option value="ResearchProgram">Programme de recherche</option>
                            <option value="FrenchUniversitiesAndSchools">Universités et écoles françaises</option>
                            <option value="OtherResearchInstitutes">Autres instituts de recherche</option>
                        </select>&nbspIdentifiant de l'organisation:
                        <input type="text" name="organisationsId">
                    </p>
                    <div id="new_chq_fund"></div>
            </fieldset>
            <fieldset>
                <legend>Champs recommandés</legend>
                    <p><label>Objectif: <textarea name="Objective"></textarea></p>
                    <p><label>Variables mesurées: <textarea name="MeasuredVariable"></textarea></p>
            </fieldset>
            <fieldset>
                <legend>Champs optionnels</legend>
                    <p><label>Ressources en ligne: </label>&nbsp<button id="res" class="add">Ajouter une ressource</button></p>
                    <p>&nbspType:
                        <select name="element" id="element">
                            <option value="info">Info</option>
                            <option value="download">Téléchargement</option>
                            <option value="doi">DOI</option>
                            <option value="webservice">Service web</option>
                        </select>&nbspURL:
                        <input type="text" name="url">
                    </p>
                    <div id="new_chq_res"></div>
            </fieldset>
            <p><input type="submit" value="Sauvegarder"></p>
            <input type="hidden" value="0" id="total_chq_mgr" name="n_mgr">
            <input type="hidden" value="0" id="total_chq_fund" name="n_fund">
            <input type="hidden" value="0" id="total_chq_res" name="n_res">
        </fieldset>
    </form>
    
    <script>
        $('.add').on('click', add);
        //$('.remove').on('click', remove);
        
        let form_producer = document.getElementById("producer");

    function add() {
      var new_chq_no = parseInt($('#total_chq_'+this.id).val()) + 1;
      var new_input = document.createElement('p');
      
      switch (this.id ){
        case "mgr":
          new_input.innerHTML = "&nbspResponsable des données:&nbsp<input type='text' name='dataManager_" + new_chq_no + "'>";
          break;
        case "fund":
            var type = document.getElementById("type");
            var select = document.createElement('select');
            select.innerHTML = type.innerHTML;
            select.name = 'type_' + new_chq_no;
            new_input.innerHTML = "&nbspType:&nbsp";
            new_input.appendChild(select);
            new_input.innerHTML = new_input.innerHTML +"&nbspIdentifiant de l'organisation:&nbsp<input type='text' name='organisationsId_" + new_chq_no + "'>";
            break;
        case "res":
            var element = document.getElementById("element");
            var select = document.createElement('select');
            select.innerHTML = element.innerHTML;
            select.name = 'element_' + new_chq_no;
            new_input.innerHTML = "&nbspType:&nbsp";
            new_input.appendChild(select);
            new_input.innerHTML = new_input.innerHTML +"&nbspURL:&nbsp<input type='text' name='url_" + new_chq_no + "'>";
            break;
        default:
            alert('Il ya un problème...');
        }
      
      $('#new_chq_'+this.id).append(new_input);

      $('#total_chq_'+this.id).val(new_chq_no);
      return false;
    }

    function remove() {
      var last_chq_no = $('#total_chq').val();

      if (last_chq_no > 1) {
        $('#new_' + last_chq_no).remove();
        $('#total_chq').val(last_chq_no - 1);
      }
    }
    
    function valider (event) {
        var chq_mgr  = document.getElementById('total_chq_mgr').value;
        var chq_fund = document.getElementById('total_chq_fund').value;
        var chq_res  = document.getElementById('total_chq_res').value;
    
        let champ_id = form_producer.elements["Identifier"];
        let champ_name = form_producer.elements["Name"];
        let champ_title = form_producer.elements["Title"];
        let champ_desc = form_producer.elements["Description"];
        let champ_email = form_producer.elements["Email"];
        let champ_proj = form_producer.elements["projectLeader"];
        let champ_data = [];
        champ_proj.value = "projectLeader:" + champ_proj.value;
        let champ_type = [form_producer.elements["type"]];
        let champ_org = [form_producer.elements["organisationsId"]];
        let champ_obj = form_producer.elements["Objective"];
        let champ_meas = form_producer.elements["MeasuredVariable"];
        let champ_el = [form_producer.elements["element"]];
        let champ_url = [form_producer.elements["url"]];
        
        for (let i = 1; i <= chq_mgr; i++) {
            champ_data.push(form_producer.elements["dataManager_"+i]);
        }
        for (let i = 1; i <= chq_fund; i++) {
            champ_type.push(form_producer.elements["type_"+i])
            champ_org.push(form_producer.elements["organisationsId_"+i]);
        }
        for (let i = 1; i <= chq_res; i++) {
            champ_url.push(form_producer.elements["url_"+i]);
            champ_el.push(form_producer.elements["element_"+i]);
        }
        for (let i = 0; i < champ_data.length-1; i++) {
            champ_data[i].value = "dataManager:" + champ_data[i].value + "_,";
        } champ_data[champ_data.length-1].value = "dataManager:" + champ_data[champ_data.length-1].value;
        for (let i = 0; i < champ_org.length-1; i++) {
                champ_org[i].value = champ_type[i].value + ":" + champ_org[i].value + "_,";
        } champ_org[champ_org.length-1].value = champ_type[champ_type.length-1].value + ":" + champ_org[champ_org.length-1].value;
        for (let i = 0; i < champ_url.length-1; i++) {
                champ_url[i].value = "http:" + champ_el[i].value + "@" + champ_url[i].value + "_,";
        } champ_url[champ_url.length-1].value = "http:" + champ_el[champ_el.length-1].value + "@" + champ_url[champ_url.length-1].value;
    }
    
    form_producer.addEventListener('submit', valider);
    
    $('#producer').on('submit', function(){
        var arr = $(this).serializeArray();
        console.log(arr);
        return false; //      /<-- Only, if you don't want the form to be submitted after above commands
    });
    </script>
  </body>
</html>
