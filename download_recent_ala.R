library(sf)
library(galah)
library(lubridate)

query <- function(taxon="Plantae", years=2024) {
  identify <- galah::galah_call() |>
    galah::galah_identify(taxon)
  
  filter <- galah::galah_filter(
    spatiallyValid == TRUE,
    species != "",
    decimalLatitude != "",
    year == years,
    basisOfRecord == c("HUMAN_OBSERVATION", "PRESERVED_SPECIMEN")
  )
  
  select <- galah::galah_select(
    recordID,
    species,
    genus,
    family,
    decimalLatitude,
    decimalLongitude,
    coordinateUncertaintyInMeters,
    eventDate,
    datasetName,
    basisOfRecord,
    references,
    institutionCode,
    recordedBy,
    outlierLayerCount,
    isDuplicateOf,
    sounds
  )
  
  identify$filter <- filter
  identify$select <- select
  
  return(identify)
}



# Define the function with simplification
download_observations_bbox <- function(kml_file_path, start_date) {
  area <- sf::st_read(kml_file_path, quiet = TRUE)
  bbox <- sf::st_bbox(area)
  wkt_bbox <- paste(
    "POLYGON((",
    bbox["xmin"],
    bbox["ymin"],
    ",",
    bbox["xmin"],
    bbox["ymax"],
    ",",
    bbox["xmax"],
    bbox["ymax"],
    ",",
    bbox["xmax"],
    bbox["ymin"],
    ",",
    bbox["xmin"],
    bbox["ymin"],
    "))"
  )
  
  
  download <- query() |>
    galah_geolocate(wkt = wkt_bbox) |>
    atlas_occurrences()
  
  download %>%
    dplyr::filter(is.na(coordinateUncertaintyInMeters) |
                    coordinateUncertaintyInMeters <= 1000) ->out
  
  
  return(out)
}

geo_filter <- function(kalb, kml) {
  kalb <- filter(kalb, !is.na(decimalLatitude))
  df_sf <-
    st_as_sf(
      kalb,
      coords = c("decimalLongitude", "decimalLatitude"),
      crs = st_crs(kml)
    )
  kalb$inside_kml <- st_within(df_sf, kml, sparse = FALSE)
  kalb <- filter(kalb, inside_kml)
  return(kalb)
}


royal_kml <- st_read("royal national park.kml")
royal_obs <- download_observations_bbox("royal national park.kml", dmy("1-10-2024"))
royal_only_obs <- geo_filter(royal_obs, royal_kml)


accepted_new_names <- APCalign::create_taxonomic_update_lookup(unique(royal_only_obs$species))
alltime_org <- read.csv("royal_alltime_flora.csv")
alltime <- APCalign::create_taxonomic_update_lookup(unique(alltime_org$accepted_name))
putative_new_species <- stringr::word(unique(accepted_new_names$accepted_name), 1, 2)

new<-putative_new_species[!putative_new_species %in% alltime$accepted_name & 
                            !putative_new_species %in% alltime$aligned_name]

z<-native_anywhere_in_australia(new)
