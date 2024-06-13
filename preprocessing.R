#Including all your code index.qmd and rendering it each time you want to preview your report makes your report less error prone and more reproducible, 
#but this workflow can be cumbersome when the code takes a long time to execute. 
#This prevents you iterating fast when writing up your report. We suggest the following method to solve this:
#Outsource your preprocessing steps and especially the heavy computation into a seperate R-Script called preprocessing.R. 
#In this script, generate all outputs that you will need in your report (index.qmd).
#To “prove” that this script runs on your machine from top to bottom, in a new session and without any errors, use the function 
knitr::spin("preprocessing.R") 
#from the package knitr (you might need to install this first). 
#Push the resulting files (preprocessing.html / preprocessing.md) to GitHub (this is a hard requirement).###

# install.packages("XML")
# install.packages("gitcreds")
library("readr")
library(sf) #simple features 
library(ggplot2)
library(dplyr)
library("gitcreds")
library(XML) #to read the XML data of gpx files
library(tmap) #to show data in map viewer
#library(leaflet) #alternative to show in a map
library(lubridate) # time
library(knitr) #To “prove” that script runs on your machine from top to bottom
#install.packages("slider")
library(slider) # for "sliding" over the datapoints (similar to leadlag or roll)
#install.packages("factoextra")
#install.packages("cluster")
library(factoextra)#kmeans
library(cluster)#kmeans
library(zoo) # for sinuosity
#install.packages("vegan")
library(vegan) # for k means partitioning

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
  
  dfname <- print(substring(gpx_path, 17, 34)) #extract trajectory names
  df$rec_id <- dfname #add column with traj-name to df
  assign(dfname, df, envir = .GlobalEnv) # add traj-name to df
}

# Iterate over each file and apply your function
for (file_path in file_list) {
  gpx_to_df(file_path)
}

# Combine single track-files to one Dataframe
dflist_Laura <- substring(file_list,17,34)
dflist_Laura
all_tracks_Laura <- do.call(rbind, lapply(dflist_Laura, get))

# Delete single track files from environment
rm(list= dflist_Laura)

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

# Specify TRajID --> To differentiate between the different records, I would like to assign an ID next to the name. This is also to ensure, that if there were tracks with the same name, their fixes are not combined. 
## Create function
rle_id <- function(vec) {
  x <- rle(vec)$lengths
  as.factor(rep(seq_along(x), times = x))
}
## Apply function to run along record_names
all_tracks_Laura <- all_tracks_Laura |>
  mutate(trajID = rle_id(rec_id))

# choose 3 exemplary trajectories (of mixed movement?)
trajIDs <- c(3, 9, 12)

laura_df <- all_tracks_Laura |> 
  filter(trajID %in% trajIDs)

tmap_mode("view")
tm_shape(laura_df)+ 
  tm_dots(col = "trajID", palette = "Paired") 

#### calculate the parameters ####

# Distanz FUnktion
distance_by_element <- function(later, now) {
  as.numeric(
    st_distance(later, now, by_element = TRUE)
  )
}
# Movement Parameter
laura_df <- laura_df |> 
  group_by(trajID) |>  # Gruppieren nach trajID
  mutate(
    distance = distance_by_element(geometry, lead(geometry, 1)), # distance to pos +1
    time_diff = as.numeric(timestamp - lag(timestamp)),
    speed = distance / time_diff,
    speed_kmh = speed * 3.6, # round ist hier vllt sinnvoll? round(speed*3.6)
    acceleration = (speed - lag(speed)) / time_diff,
    # aus dem package slider, berechnet die gleitende Summe der Werte über 10 Punkte
    avg_speed_10s = slide_dbl(speed_kmh, mean, .before = 5, .after = 5, .complete = TRUE),
    avg_speed_60s = slide_dbl(speed_kmh, mean, .before = 30, .after = 30, .complete = TRUE), 
    # aufpassen! Hier gehen die ersten 60 Datenpunkte verloren!
    max_speed_10s = slide_dbl(speed_kmh, max, .before = 5, .after = 5, .complete = TRUE),
    avg_acc_10s = slide_dbl(acceleration, mean, .before = 5, .after = 5, .complete = TRUE) ,
    avg_acc_60s = slide_dbl(acceleration, mean, .before = 30, .after = 30, .complete = TRUE),
    max_acc_10s = slide_dbl(acceleration, max, .before = 5, .after = 5, .complete = TRUE),
    el_change = (elevation -lag(elevation,  10)), #given in meters/10 datapooints, not sure if correct or makes sense!
    d_direct10 = distance_by_element(lag(geometry,4), lead(geometry,5)),
    d_sinu10 = rollsum(distance, 10,align = "center", fill = NA), # function rollsum does basically the same as slide, was recommended by nils
    #Bei der Verwendung der rollsum-Funktion mit Fenstergröße von 10, werden die Datenpunkte so zentriert, dass die Summe der 5 Punkte vor und der 4 Punkte nach dem aktuellen Punkt berechnet wird.
    d_direct10 = case_when(d_direct10 == 0 ~ d_sinu10,
                           TRUE ~ d_direct10),
    #diese Abänderung von d_direct ist nötig, damit die sinuosity richtig berechnet wird und keine Inf Values herauskommen (wegen Nenner=0)
    sinuosity = d_sinu10/d_direct10   ) |> 
  ungroup()



#### k-means Analysis #### 


#### Functions  #### 

# Function hcoplot()
# Reorder and plot dendrogram with colors for groups and legend
# Usage:
# hcoplot(tree = hclust.object, diss = dissimilarity.matrix, k = nb.clusters, 
#	title = paste("Reordered dendrogram from",deparse(tree$call),sep="\n"))
#
# License: GPL-2 
# Author: Francois Gillet, 23 August 2012
# Revised: Daniel Borcard, 31 August 2017

"hcoplot" <- function(tree, 
                      diss, 
                      lab = NULL,
                      k, 
                      title = paste("Reordered dendrogram from", 
                                    deparse(tree$call), 
                                    sep="\n"))
{
  require(gclus)
  gr <- cutree(tree, k=k)
  tor <- reorder.hclust(tree, diss)
  plot(tor, 
       labels = lab,
       hang=-1, 
       xlab=paste(length(gr),"sites"), 
       sub=paste(k,"clusters"), 
       main=title)
  so <- gr[tor$order]
  gro <- numeric(k)
  for (i in 1 : k)
  {
    gro[i] <- so[1]
    if (i<k) so <- so[so!=gro[i]]
  }
  rect.hclust(tor, 
              k = k, 
              border = gro + 1, 
              cluster = gr)
  legend("topright", 
         paste("Cluster", 1 :k ), 
         pch = 22, 
         col = 2 : (k + 1), 
         bty = "n")
}
