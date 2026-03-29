<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title id="PageTitle"></title>
    <!-- Styles CSS -->
    <link rel="stylesheet" href="styles.css">
    <!-- Leaflet.js -->
    <link rel="stylesheet" href="leaflet/leaflet.css" />
    <!-- Lien vers le fichier JavaScript (leaflet) local -->
    <script src="leaflet/leaflet.js"></script>
    <!-- Liens vers les librairies leaflet locales pour afficher les fleches de vecteurs et les ellipses d'erreurs-->
    <script src="leaflet/ellipse.js"></script>
    <script src="leaflet/leaflet.geometryutil.js"></script>
    <script src="leaflet/leaflet-arrowheads.js"></script>  
</head>
<body>
    <div class="container">
        <h2 id="procTitle"></h2>

        <!-- Slider de date -->
        <label for="dateSlider" id="dateLabel">Date :</label>
        <input type="range" id="dateSlider" >

        <!-- Slider de période -->
      
        <label for="periodSlider">Time Window :</label>
        <input type="range" id="periodSlider" >
        <span id="selectedPeriodLabel"></span>
      
        
        <!--Slider d'échelle-->
        <label for="scaleSlider">Scale :</label>
        <input type="range" id="scaleSlider" min="1" max="10" step ="1" value="5">
        <span id="selectedScale"></span>

        <!-- Carte Leaflet pour les vecteurs  -->
        <div id="map" style="height:400px;"></div>
        
    </div>
    <!-- Boutons pour afficher/cacher les vecteurs horizontaux et verticaux-->
    <div class="button-container">
        <button id="toggleHorizontal">Hide horizontal vectors</button>
        <button id="toggleVertical">Hide vertical vectors</button>
        <button id="toggleHorizontalError">Hide horizontal error vectors</button>
        <button id="toggleVerticalError">Hide vertical error vectors</button>
    </div>
    <!-- Lien vers le fichier JavaScript d'interactions avec la carte-->
    <script type="module" src="script.js"></script>
</body>
</html>
