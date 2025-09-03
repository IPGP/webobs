import pyproj
import utm

if __name__ == "__main__":

## --> chose your input coordinate format <--

    # UTM
    easting = 368042
    northing = 7650658

## --> chose the UTM zone <--
    utm_zone = 27  # 40
    utm_hemisphere = 'N'  # 'S'
    desired_zone = utm_zone, utm_hemisphere

    # degrees (decimal degress)
    latitude = 63.90198
    longitude = 22.20947

    # Degrees, Minutes
    latitude_deg_min = (63, 53.434)
    longitude_deg_min = (-22,-13.418)

    # Degrees, Minutes, Seconds (DMS)
    latitude_dms = (-21, -16, -19.8)
    longitude_dms = (55,44,15.2)

    def convertUTMtodegree(easting,northing):

        utm_proj = pyproj.Proj(proj='utm', zone=utm_zone, south=True)
        lon, lat = utm_proj(easting, northing, inverse=True)
        print("Input (UTM):", "E", easting, ", N", northing)
        print(f"Output (Decimal Degrees): {lat}, {lon}")
        print("Output (Degrees, minutes, seconds):")
        degrees, minutes, seconds = decimal_degrees_to_dms(lat)
        degrees, minutes, seconds = decimal_degrees_to_dms(lon)
    def convertdegreetoUTM(latitude,longitude):
        # Convert latitude and longitude to UTM coordinates in the desired zone
        easting, northing, zone_number, zone_letter = utm.from_latlon(latitude, longitude,
                                                                      force_zone_number=desired_zone[0],
                                                                      force_zone_letter=desired_zone[1])
        print("Input (Decimal degres):", "lat:", latitude,", long:" ,longitude)
        print(f"output UTM : Easting = {easting}, Northing = {northing}, Zone: {desired_zone}")
    def decimal_degrees_to_dms(decimal_degrees):
        degrees = int(decimal_degrees)
        decimal_minutes = (decimal_degrees - degrees) * 60
        minutes = int(decimal_minutes)
        seconds = (decimal_minutes - minutes) * 60
        print(f"{degrees}° {minutes}' {seconds}''")
        return degrees, minutes, seconds
    def dms_to_decimal_utm(latitude_dms, longitude_dms):
        latitude_deg = latitude_dms[0] + latitude_dms[1] / 60 + latitude_dms[2] / 3600
        longitude_deg = longitude_dms[0] + longitude_dms[1] / 60 + longitude_dms[2] / 3600
        easting, northing, zone_number, zone_letter = utm.from_latlon(latitude_deg, longitude_deg,
                                                                      force_zone_number=desired_zone[0],
                                                                      force_zone_letter=desired_zone[1])
        print("Input (DMS):", latitude_dms, longitude_dms)
        print("output(decimal degree):","Lat, long :", latitude_deg, longitude_deg)
        print(f"output UTM : Easting = {easting}, Northing = {northing}, Zone: {desired_zone}")
    def deg_min_to_UTM(latitude_deg_min,longitude_deg_min):
        # Convertir les coordonnées degrés et minutes en degrés décimaux
        latitude_deg = latitude_deg_min[0] + latitude_deg_min[1] / 60
        longitude_deg = longitude_deg_min[0] + longitude_deg_min[1] / 60
        easting, northing, zone_number, zone_letter = utm.from_latlon(latitude_deg, longitude_deg,
                                                                      force_zone_number=desired_zone[0],
                                                                      force_zone_letter=desired_zone[1])
        print("Input (degrees minutes):", latitude_deg_min,longitude_deg_min)
        print("output(decimal degree):","Lat, long :", latitude_deg, longitude_deg)
        print(f"output UTM : Easting = {easting}, Northing = {northing}, Zone: {desired_zone}")

# --> choose what conversion you want <--

    #--> Convert DMS to decimal degree and to UTM
    #dms_to_decimal= dms_to_decimal_utm(latitude_dms, longitude_dms)

    #--> Convert degrees minutes to decimal degree and to UTM
    #deg_min_to_UTM= deg_min_to_UTM(latitude_deg_min,longitude_deg_min)

    #--> Convert degrees minutes to UTM
    #convertdegreetoUTM=convertdegreetoUTM(latitude, longitude)

    #--> Convert UTM to degree minutes and DMS
    convertUTMtodegree = convertUTMtodegree(easting, northing)
