
<!-- README.md is generated from README.Rmd. Please edit that file -->

# A dynamic lookup to help curate the “all time” plant species list for Royal National Park, NSW, Australia

Versioned data for the “all time” flora of Royal National Park, NSW,
Australia. The R script checks the ALA for species that are candidates
for new discoveries since the list was created and prints out the list
of those candidates for new discoveries. These new discoveries may arise
from new collections at herbaria or from citizen scientists.

Note that some of these “new” species arise from the different rates of
taxonomic updates in the different data resources. These need manual
curation before adding new species to the all-time list.

### First load some libraries and helper functions:

``` r
source("download_recent_ala_functions.R")
```

### Then there are a few steps to the process:

1.  Download the 2024 or later data from ALA

``` r
royal_kml <- st_read("royal national park.kml")
```

    ## Reading layer `rnp' from data source 
    ##   `/Users/z3484779/Documents/royalNP_alltime_flora/royal national park.kml' 
    ##   using driver `KML'
    ## Simple feature collection with 1 feature and 2 fields
    ## Geometry type: MULTIPOLYGON
    ## Dimension:     XYZ
    ## Bounding box:  xmin: 150.9916 ymin: -34.22679 xmax: 151.1718 ymax: -34.04006
    ## z_range:       zmin: 0 zmax: 0
    ## Geodetic CRS:  WGS 84

``` r
royal_obs <- download_observations_bbox(
  "royal national park.kml", start_year = 2024)
```

    ## Request for 2726 occurrences placed in queue
    ## Current queue length: 1

    ## --

    ## Downloading

``` r
royal_only_obs <- geo_filter(royal_obs, royal_kml)
```

    ## st_as_s2(): dropping Z and/or M coordinate

    ## Warning: Using one column matrices in `filter()` was deprecated in dplyr 1.1.0.
    ## ℹ Please use one dimensional logical vectors instead.
    ## This warning is displayed once every 8 hours.
    ## Call `lifecycle::last_lifecycle_warnings()` to see where this warning was
    ## generated.

2.  trying to wrangle taxonomy to APC for both lists, using the APCalign
    package

``` r
resources <- APCalign::load_taxonomic_resources(quiet = TRUE)
```

``` r
accepted_new_names <- APCalign::create_taxonomic_update_lookup(
  unique(royal_only_obs$species, resources = resources, quiet = TRUE))
```

    ## Loading resources into memory...

    ## ================================================================================================================================================================

    ## ...done

    ## Checking alignments of 580 taxa

    ##   -> of these 551 names have a perfect match to a scientific name in the APC. 
    ##       Alignments being sought for remaining names.

``` r
alltime_org <- read.csv("royal_alltime_flora.csv")
alltime <- APCalign::create_taxonomic_update_lookup(
  unique(alltime_org$accepted_name), resources = resources, quiet = TRUE)
putative_new_species <- stringr::word(
  unique(accepted_new_names$accepted_name), 1, 2)
```

3.  figure out new names that appeared in 2024 (or later) that are not
    in the all time list

``` r
new_discoveries <- setdiff(putative_new_species, 
                           union(alltime$accepted_name, 
                                 alltime$aligned_name))
```

4.  Compare with native/introduced lookup table (note that this
    considers native anywhere in Australia as native)

``` r
nat_lookup <- native_anywhere_in_australia(new_discoveries, 
                                           resources=resources)
```

5.  calculate number of 2024 or later observations for the set of
    potentially new species, to help evaluate the candidate list.

``` r
royal_only_obs %>% 
  group_by(species) %>% 
  summarize(number_of_recent_obs = n()) %>% 
  right_join(nat_lookup) %>% 
  filter(!is.na(number_of_recent_obs)) %>%
  print(n = Inf)
```

    ## Joining with `by = join_by(species)`

    ## # A tibble: 24 × 3
    ##    species                number_of_recent_obs native_anywhere_in_aus
    ##    <chr>                                 <int> <chr>                 
    ##  1 Agave americana                           1 introduced            
    ##  2 Aloe maculata                             1 introduced            
    ##  3 Cakile maritima                           1 introduced            
    ##  4 Cardamine hirsuta                         2 introduced            
    ##  5 Cissus antarctica                         3 native                
    ##  6 Cissus hypoglauca                         5 native                
    ##  7 Digitaria violascens                      1 introduced            
    ##  8 Dioscorea transversa                      1 native                
    ##  9 Fraxinus griffithii                       1 introduced            
    ## 10 Harpephyllum caffrum                      1 introduced            
    ## 11 Macadamia tetraphylla                     1 native                
    ## 12 Passiflora suberosa                       2 introduced            
    ## 13 Petrorhagia dubia                         1 introduced            
    ## 14 Phoenix canariensis                       2 introduced            
    ## 15 Senecio pterophorus                       1 introduced            
    ## 16 Silybum marianum                          1 introduced            
    ## 17 Soliva sessilis                           3 introduced            
    ## 18 Sonchus asper                             1 introduced            
    ## 19 Syagrus romanzoffiana                     1 introduced            
    ## 20 Thelymitra longiloba                      1 native                
    ## 21 Trifolium cernuum                         1 introduced            
    ## 22 Verbascum virgatum                        2 introduced            
    ## 23 Veronica arvensis                         1 introduced            
    ## 24 Viburnum odoratissimum                    1 introduced
