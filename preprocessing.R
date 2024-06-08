#Including all your code index.qmd and rendering it each time you want to preview your report makes your report less error prone and more reproducible, 
#but this workflow can be cumbersome when the code takes a long time to execute. 
#This prevents you iterating fast when writing up your report. We suggest the following method to solve this:
#Outsource your preprocessing steps and especially the heavy computation into a seperate R-Script called preprocessing.R. 
#In this script, generate all outputs that you will need in your report (index.qmd).
#To “prove” that this script runs on your machine from top to bottom, in a new session and without any errors, use the function 
knitr::spin("preprocessing.R") 
#from the package knitr (you might need to install this first). 
#Push the resulting files (preprocessing.html / preprocessing.md) to GitHub (this is a hard requirement).###

library("readr")
library(sf) #simple features 
library(ggplot2)
library(dplyr)
library("gitcreds")
library(XML) #to read the XML data of gpx files
library(leaflet) #to show in a map
library(lubridate) # time
library(knitr) #To “prove” that script runs on your machine from top to bottom
library(slider) # for "sliding" over the datapoints (similar to leadlag or roll)
library(factoextra)#kmeans
library(cluster)#kmeans

### Data Loading and Organisation
laura_act <- read.csv("data/activities_Laura.csv")

# Get a list of files in the folder
folder_path <- "data/activities_Laura/"
file_list <- list.files(folder_path, full.names = TRUE)

#Create a function that assigns coordinates, elevation, time and activity name out of the gpx file, then apply this function to all of the gpx files:
gpx_to_df <- function(gpx_path) {
  gpx_parsed <- htmlTreeParse(file = gpx_path, useInternalNodes = TRUE)
  # read out elements of the html file to vecotrs
  coords <- xpathSApply(doc = gpx_parsed, path = "//trkpt", fun = xmlAttrs)
  elevation <- xpathSApply(doc = gpx_parsed, path = "//trkpt/ele", fun = xmlValue)
  time <- xpathSApply(doc = gpx_parsed, path = "//time", fun = xmlValue)
  activity_name <- xpathSApply(doc = gpx_parsed, path = "//name", fun = xmlValue)
  activity_type <- xpathSApply(doc = gpx_parsed, path = "//type", fun = xmlValue)
  # remove first value of time, as it stems from the metadata and matches the second value (i.e. first timestamp of trackpoint)
  time <- time[-1]
  # convert vectors to a data frame
  df <- data.frame(
    lat = as.numeric(coords["lat", ]),
    lon = as.numeric(coords["lon", ]),
    elevation = as.numeric(elevation), 
    timestamp = as.POSIXct(time,tz="UTC", format=c("%Y-%m-%dT%H:%M:%OS")),
    ActivityName = activity_name,
    ActivityType = activity_type
  ) 
  dfname <- print(substring(gpx_path, 12, 34))
  assign(dfname, df, envir = .GlobalEnv)
}

# Iterate over each file and apply your function
for (file_path in file_list) {
  gpx_to_df(file_path)
}

# Combine single track-files to one Dataframe
dflist_Laura <- substring(file_list,12,34)
dflist_Laura
all_tracks_Laura <- do.call(rbind, lapply(dflist_Laura, get))

# Converting the df to sf object
library(sf)
all_tracks_Laura <- st_as_sf(all_tracks_Laura, coords = c("lon", "lat"), crs = 4326)
str(all_tracks_Laura)

# Transforming the crs to CH1903 +LV95 or EPSG:2056 & Timezone
all_tracks_Laura <- st_transform(all_tracks_Laura, 2056)
str(all_tracks_Laura)
# Check Timezone
attr(all_tracks_Laura$timestamp, "tzone")

#  Filtering out old data
all_tracks_Laura <- all_tracks_Laura |> 
  mutate("year" = year(timestamp)) |> #for this use library lubridate
  filter(year == 2024)


distance_by_element <- function(later, now) {
  as.numeric(
    st_distance(later, now, by_element = TRUE)
  )
}



laura_df <- laura_df |> 
  group_by(trajID) |>  # Gruppieren nach trajID
  mutate(
    distance = distance_by_element(geometry, lead(geometry, 1)), # distance to pos +1
    time_diff = c(NA, difftime(timestamp[-1], timestamp[-length(timestamp)], units = "secs")),
    speed = distance / time_diff,
    speed_kmh = speed * 3.6, # round ist hier vllt sinnvoll? round(speed*3.6)
    acceleration = (speed - lag(speed)) / time_diff,
    # aus dem package slider, berechnet die gleitende Summe der Werte über 10 Punkte
    avg_speed_10s = slide_dbl(speed_kmh, sum, .before = 5, .after = 5, .complete = TRUE) /
      slide_dbl(time_diff, sum, .before = 5, .after = 5, .complete = TRUE),
    avg_speed_60s = slide_dbl(speed_kmh, sum, .before = 30, .after = 30, .complete = TRUE) /
      slide_dbl(time_diff, sum, .before = 30, .after = 30, .complete = TRUE), 
    # aufpassen! Hier gehen die ersten 60 Datenpunkte verloren!
    max_speed_10s = slide_dbl(speed_kmh, max, .before = 5, .after = 5, .complete = TRUE),
    avg_acc_10s = slide_dbl(acceleration, sum, .before = 5, .after = 5, .complete = TRUE) /
      slide_dbl(time_diff, sum, .before = 5, .after = 5, .complete = TRUE),
    avg_acc_60s = slide_dbl(acceleration, sum, .before = 30, .after = 30, .complete = TRUE) /
      slide_dbl(time_diff, sum, .before = 30, .after = 30, .complete = TRUE),
    max_acc_10s = slide_dbl(acceleration, max, .before = 5, .after = 5, .complete = TRUE),
    el_change = (elevation -lag(elevation,  10)) #given in meters/10 datapooints, not sure if correct or makes sense!
  ) |> 
  ungroup()
