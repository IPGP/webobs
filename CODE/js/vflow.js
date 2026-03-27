// Map initialization
let map = L.map('map');

// Display variables (modifiable)
let scale_factor = 10000; // Scaling factor for vectors
let horizontal_color = 'red'; // Color for horizontal vectors
let vertical_color = 'green'; // Color for vertical vectors
let tiles = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'; // Tile layer URL
let tiles_sources = '&copy; OpenStreetMap contributors'; // Attribution for tile sources


// Setting up map tiles as the background layer
L.tileLayer(tiles, {
    attribution: tiles_sources
}).addTo(map);


// Adds a scale of the map at the bottom left
L.control.scale({ imperial: false }).addTo(map);


//  Layer groups for map elements (vectors, errors, scale)
let vectorLayer = L.layerGroup().addTo(map); // Horizontal vectors
let errorLayer = L.layerGroup().addTo(map); // Horizontal error ellipses
let stationMarkers = L.layerGroup().addTo(map); // GNSS station markers
let scaleLayer = L.layerGroup().addTo(map); // Custom scale for the vectors display
let verticalVectorLayer = L.layerGroup().addTo(map); // Vertical vectors
let verticalErrorLayer = L.layerGroup().addTo(map); // Vertical error circles


//  Handling sliders and buttons
let dateSlider = document.getElementById("dateSlider"); // Slider for selecting enddate
let periodSlider = document.getElementById("periodSlider"); // Slider for selecting time period
let scaleSlider = document.getElementById("scaleSlider"); // Slider for adjusting vector scale
let toggleHorizontalButton = document.getElementById("toggleHorizontal"); // Button to toggle horizontal vectors
let toggleVerticalButton = document.getElementById("toggleVertical"); // Button to toggle vertical vectors
let toggleHorizontalErrorButton = document.getElementById("toggleHorizontalError"); // Button to toggle horizontal error vectors
let toggleVerticalErrorButton = document.getElementById("toggleVerticalError"); // Button to toggle vertical error vectors


//  Associated text elements for sliders
let selectedDateDisplay = document.getElementById("selectedDate"); // Display for selected date
let selectedPeriodLabel = document.getElementById("selectedPeriodLabel"); // Display for selected time period
let selectedScale = document.getElementById("selectedScale"); // Display for selected scale
let dateLabel = document.getElementById('dateLabel'); // Display for date range


//  Global variables for GNSS data management
let gnssData = []; // Array to store GNSS data
let availableDates = []; // Array of available dates
let availablePeriods = []; // Array of available time periods
let stationsInfo = []; // Array of station information
let CustomScaleControl = null; // Custom scale control element
let CustomScale = null; // Custom scale value

//......................................... GNSS data loading function ...........................................//
/**
 * Loads GNSS data from the server.
 * Retrieves data from a server-side Perl or PHP script (process.pl).
 * Updates the page title and station information.
 * Adjusts sliders for date and period selection based on retrieved data.
 * Initializes the map view and updates vectors.
 */
function loadGNSSData() {
    fetch("process.pl") // Calls the server-side script to get GNSS data
        .then(response => response.json()) // Parses the JSON response
        .then(data => {
            let proc = data.proc; // Process name
            document.getElementById("PageTitle").textContent = proc; // Update page title
            document.getElementById("procTitle").textContent = proc; // Update process title
            gnssData = data.data; // Assign GNSS data
            stationsInfo = data.stations; // Assign station data
            availableDates = Object.keys(gnssData).sort(); // Extract and sort dates
            availablePeriods = Object.values(data.periods); // Get available periods

            // Set up period slider
            if (availablePeriods.length > 0) {
                periodSlider.min = 0;
                periodSlider.max = availablePeriods.length - 1;
                periodSlider.value = 0;
            }

            // Set up date slider
            if (availableDates.length > 0) {
                dateSlider.min = 0;
                dateSlider.max = availableDates.length - 1;
                dateSlider.value = 0;
            }

            adjustMapView(); // Adjust map view to fit all stations
            updateVectors(dateSlider.value, periodSlider.value); // Update vectors on the map
        });
}

// .............................. End of GNSS data loading function ........................................... //

// .............................. Scale update ........................................... .................;//

// Functions to define the scale ratio

/**
 * Calculate the vector length in pixels
 * @param {L.LatLng} startPoint - Starting point of the vector
 * @param {L.LatLng} endPoint - Ending point of the vector
 * @returns {number} Vector length in pixels
 */
function getVectorLengthInPixels(startPoint, endPoint) {
    let pixelStart = map.latLngToContainerPoint(startPoint); // Convert geographic coordinates to pixel coordinates
    let pixelEnd = map.latLngToContainerPoint(endPoint); // Same for the endpoint
    return pixelStart.distanceTo(pixelEnd); // Calculate pixel distance between points
}

/**
 * Calculate the real vector length in meters
 * @param {L.LatLng} startPoint - Starting point of the vector
 * @param {L.LatLng} endPoint - Ending point of the vector
 * @returns {number} Real vector length in meters
 */
function getRealVectorLength(startPoint, endPoint) {
    return map.distance(startPoint, endPoint); // Calculate geographical distance between points
}

/**
 * Update the scale using vector coordinates
 * @param {L.LatLng} vectorStart - Starting point of the vector
 * @param {L.LatLng} vectorEnd - Ending point of the vector (on screen)
 * @param {L.LatLng} vectorEndReal - Real ending point of the vector (geographical)
 */
function updateScaleFromVector(vectorStart, vectorEnd, vectorEndReal) {
    let vectorLengthPixels = getVectorLengthInPixels(vectorStart, vectorEnd); // Length in pixels
    let vectorLengthMeters = getRealVectorLength(vectorStart, vectorEndReal); // Length in meters
    if (vectorLengthMeters === 0) return;

    let scaleInMM = (100 / vectorLengthPixels) * vectorLengthMeters; // Scale calculation in millimeters
    selectedScale.textContent = `Vectors: ${scaleInMM.toFixed(1)} mm`;

    // Remove existing scale control if present
    if (CustomScaleControl) map.removeControl(CustomScaleControl);

    // Create and add a new custom scale control to the map
    CustomScaleControl = new (L.Control.extend({
        onAdd: () => {
            let div = L.DomUtil.create('div', 'custom-scale');
            div.innerHTML = `<strong>Vectors: <span id="scaleValue">${scaleInMM.toFixed(1)}</span> mm</strong>`;
            let scaleLine = L.DomUtil.create('div', 'scale-line');
            scaleLine.style.width = '100px';
            div.appendChild(scaleLine);
            return div;
        }
    }))({ position: 'bottomleft' });

    map.addControl(CustomScaleControl); // Add the custom scale control to the map
}

// .................................... End of scale update ............................................ //

/**
 * Convert metric coordinates to geographic coordinates (latitude and longitude)
 * @param {number} lat - Latitude of the starting point
 * @param {number} lon - Longitude of the starting point
 * @param {number} deltaE - Eastward displacement in meters
 * @param {number} deltaN - Northward displacement in meters
 * @returns {number[]} Array containing new latitude and longitude
 */
function metersToLatLon(lat, lon, deltaE, deltaN) {
    const earthRadius = 6371000; // Earth radius in meters
    const deltaLat = deltaN / earthRadius * (180 / Math.PI); // Convert meters to latitude degrees
    const deltaLon = (deltaE / (earthRadius * Math.cos(lat * Math.PI / 180))) * (180 / Math.PI); // Convert meters to longitude degrees
    return [lat + deltaLat, lon + deltaLon];
}

/**
 * Adjust the map view to include all stations at the start
 * Creates a bounding box that fits all station markers
 */
function adjustMapView() {
    let bounds = L.latLngBounds(); // Create a LatLngBounds object

    // Add each station's coordinates to the bounding box
    for (let stationFileName in stationsInfo) {
        let stationInfo = stationsInfo[stationFileName];
        let position = [stationInfo.latitude, stationInfo.longitude];
        bounds.extend(position);
    }

    // Fit the map view to include all stations
    map.fitBounds(bounds);
}


//.................................Update vectors....................................................//

/**
 * Update the vectors on the map based on selected date and period.
 * Clears existing layers and redraws the vectors and errors.
 * @param {number} dateIndex - Index of the selected date
 * @param {number} periodIndex - Index of the selected period
 */
function updateVectors(dateIndex, periodIndex) {
    const selectedDate = availableDates[dateIndex];
    const selectedPeriod = availablePeriods[periodIndex];
    const dateLabel = document.getElementById('dateLabel');
    const endDate = new Date(selectedDate); // Convert selected date to Date object
    const startDate = new Date(endDate); // Clone the end date
    startDate.setDate(endDate.getDate() - Number(selectedPeriod)); // Calculate the start date based on the period

    // Display the date range and period
    dateLabel.textContent = `Start Date: ${startDate.toISOString().split('T')[0]} - End Date: ${selectedDate}`;
    selectedPeriodLabel.textContent = `${selectedPeriod} Days`;

    // Get GNSS data for the selected date
    const stationsData = gnssData[selectedDate];

    // Clear all layers before updating
    [vectorLayer, errorLayer, verticalErrorLayer, stationMarkers, verticalVectorLayer].forEach(layer => layer.clearLayers());

    let firstVectorStart = null, firstVectorEnd = null, firstVectorEndReal = null;

    // Iterate over each station's data
    for (const stationFileName in stationsData) {
        const stationData = stationsData[stationFileName];
        const stationInfo = stationsInfo[stationFileName];
        const position = { lat: stationInfo.latitude, lon: stationInfo.longitude };
        const { vector, error } = stationData.vectors[selectedPeriod] || {};
        const startPoint = [position.lat, position.lon];
        const scaleFactor = scaleSlider.value * scale_factor / 1000;

        // Calculate the vector's end point using the scale factor
        const endPoint = metersToLatLon(startPoint[0], startPoint[1], vector[0] * scaleFactor, vector[1] * scaleFactor);
        
        // Station marker
        L.circleMarker(startPoint, { radius: 4, color: "black", fillOpacity: 0 })
            .addTo(stationMarkers)
            .bindPopup(`
                <b>Station:</b> ${stationInfo.name}<br>
                <b>Code:</b> ${stationInfo.code}<br>
                <b>URL:</b> <a href="${stationInfo.url}" target="_blank">${stationInfo.url}</a>
            `);

        // Check if the vector is valid 
        if (vector[0] === 0 || vector[1] === 0 || vector[2] === 0) {
            continue; // Skip to the next station if the vector is empty or invalid
        }

        // Save the first valid vector for scale calculation
        if (!firstVectorStart) {
            firstVectorStart = startPoint;
            firstVectorEnd = endPoint;
            firstVectorEndReal = metersToLatLon(startPoint[0], startPoint[1], vector[0], vector[1]);
        }

        // Horizontal vector
        L.polyline([startPoint, endPoint], { color: horizontal_color })
            .arrowheads({ yawn: 40, fill: true }) // Add arrowheads to the polyline
            .addTo(vectorLayer);

        // Horizontal error ellipse
        const errorRadiusX = Math.sqrt(error[0] ** 2) * scaleFactor;
        const errorRadiusY = Math.sqrt(error[1] ** 2) * scaleFactor;
        L.ellipse(endPoint, [errorRadiusX, errorRadiusY], 0, {
            color: horizontal_color,
            fillOpacity: 0.3,
            stroke: false,
        }).addTo(errorLayer);

        // Vertical vector
        const verticalEndPoint = metersToLatLon(startPoint[0], startPoint[1], 0, vector[2] * scaleFactor);
        L.polyline([startPoint, verticalEndPoint], { color: vertical_color })
            .arrowheads({ yawn: 40, fill: true }) // Add arrowheads to the vertical vector
            .addTo(verticalVectorLayer);

        // Vertical error circle
        const verticalErrorRadius = error[2] * scaleFactor;
        L.circle(verticalEndPoint, {
            radius: verticalErrorRadius,
            color: vertical_color,
            fillOpacity: 0.3,
            stroke: false,
        }).addTo(verticalErrorLayer);
    }

    // Update the map scale based on the first valid vector
    updateScaleFromVector(firstVectorStart, firstVectorEnd, firstVectorEndReal);
}

// ......................End of update vectors....................................................//


//.......................Map event listeners......................................................//

//  Add a button to Show/Hide horizontal vectors
toggleHorizontalButton.addEventListener("click", function(){
    if (map.hasLayer(vectorLayer)) { 
        map.removeLayer(vectorLayer);
        map.removeLayer(errorLayer);  
        toggleHorizontalButton.textContent = "Show horizontal vectors";
    } else {                       
        map.addLayer(vectorLayer);
        map.addLayer(errorLayer);     
        toggleHorizontalButton.textContent = "Hide horizontal vectors";
    }
});

// Add a button to Show/Hide vertical vectors
toggleVerticalButton.addEventListener("click", function(){
    if (map.hasLayer(verticalVectorLayer)) { 
        map.removeLayer(verticalVectorLayer);
        map.removeLayer(verticalErrorLayer); 
        toggleVerticalButton.textContent = "Show vertical vectors";
    } else {                                
        map.addLayer(verticalVectorLayer);
        map.addLayer(verticalErrorLayer); 
        toggleVerticalButton.textContent = "Hide vertical vectors";
    }
});

// Add a button to Show/Hide horizontal error
toggleHorizontalErrorButton.addEventListener("click", function(){
    if (map.hasLayer(errorLayer)) { 
        map.removeLayer(errorLayer);   
        toggleHorizontalErrorButton.textContent = "Show horizontal error vectors";
    } else {                        
        map.addLayer(errorLayer);
        map.addLayer(errorLayer);     
        toggleHorizontalErrorButton.textContent = "Hide horizontal error vectors";
    }
});

// Add a button to Show/Hide vertical error 
toggleVerticalErrorButton.addEventListener("click", function(){
    if (map.hasLayer(verticalErrorLayer)) { 
        map.removeLayer(verticalErrorLayer); 
        toggleVerticalErrorButton.textContent = "Show vertical error vectors";
    } else {                                 
        map.addLayer(verticalErrorLayer);
        map.addLayer(verticalErrorLayer); 
        toggleVerticalErrorButton.textContent = "Hide vertical error vectors";
    }
});

//  Slider management
dateSlider.addEventListener("input", function () {      
    updateVectors(this.value, periodSlider.value);
});

periodSlider.addEventListener("input", function () {    
    updateVectors(dateSlider.value, this.value);
});

scaleSlider.addEventListener("input", function () {    
    updateVectors(dateSlider.value, periodSlider.value);
});

//  Update when zooming on the map
map.on('zoomend', function () {
    updateVectors(dateSlider.value, periodSlider.value);
});

//...............................End of map event listeners.......................................//

//  Create a legend
function createLegend() {
    let legend = L.control({ position: 'topright' });
    legend.onAdd = function () {
        let div = L.DomUtil.create('div', 'info legend');
        div.innerHTML = `
            <b>Legend</b><br>
            <i style="background-color: red; width: 10px; height: 10px; display: inline-block; border-radius: 50%;"></i> Horizontal<br>
            <i style="background-color: green; width: 10px; height: 10px; display: inline-block; border-radius: 50%;"></i> Vertical<br>
            <i style="border: 2px solid black; width: 8px; height: 8px; display: inline-block; border-radius: 50%;"></i> Station<br>
        `;
        return div;
    };
    legend.addTo(map);
}

//  Call the function to add the legend
createLegend();

//  Load data on startup
loadGNSSData();
