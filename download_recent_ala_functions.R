suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(galah))
galah_config(email = "wcornwell@gmail.com")
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(APCalign))
suppressPackageStartupMessages(library(tidyverse,warn.conflicts = FALSE))

query <- function(taxon="Plantae", cut_of_year=2024) {
  identify <- galah::galah_call() |>
    galah::galah_identify(taxon)
  
  filter <- galah::galah_filter(
    spatiallyValid == TRUE,
    species != "",
    decimalLatitude != "",
    year >= cut_of_year,
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
download_observations_bbox <- function(kml_file_path, start_year) {
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
  
  
  download <- query(cut_of_year=start_year) |>
    galah_geolocate(wkt = wkt_bbox) |>
    atlas_occurrences()
  
  #remove uncertain observations
  download %>%
    dplyr::filter(is.na(coordinateUncertaintyInMeters) |
                    coordinateUncertaintyInMeters <= 1000) ->out
  
  
  return(out)
}

geo_filter <- function(ala_data, kml) {
  ala_data <- filter(ala_data, !is.na(decimalLatitude))
  df_sf <-
    st_as_sf(
      ala_data,
      coords = c("decimalLongitude", "decimalLatitude"),
      crs = st_crs(kml)
    )
  ala_data$inside_kml <- st_within(df_sf, kml, sparse = FALSE)
  ala_data_inside <- filter(ala_data, inside_kml)
  return(ala_data_inside)
}



