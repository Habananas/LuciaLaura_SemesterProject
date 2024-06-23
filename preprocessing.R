#Push the resulting files (preprocessing.html / preprocessing.md) to GitHub (this is a hard requirement).###

#### Libraries ####

# install.packages("XML")
# install.packages("gitcreds")
library("readr")
library(sf) #simple features 
library(ggplot2)
library(dplyr)
library("gitcreds")
library(XML) #to read the XML data of gpx files
library(tmap) #to show data in map viewer
#install.packages("maptiles")
library(maptiles) # for tmap(plot)
#library(leaflet) #alternative to show in a map
library(lubridate) # time
library(knitr) #To “prove” that script runs on your machine from top to bottom
#install.packages("slider")
library(slider) # for "sliding" over the datapoints (similar to leadlag or roll)
#install.packages("factoextra") #elbow method and kmeans
#install.packages("cluster")
library(factoextra)#kmeans
library(cluster)#kmeans
library(zoo) # for sinuosity
#install.packages("vegan")
library(vegan) # for k means partitioning
#install.packages("gridExtra")
library("gridExtra") #for displaying several plots at the time with grid.arrange()
#install.packages("maptiles")
library(maptiles)


#### Data Loading and Organisation #### 

# Get a list of files in the folder
folder_path <- "activities_both/" # folder with only the selected tracks
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

dflist <- substring(file_list,17,34)
dflist
all_tracks <- do.call(rbind, lapply(dflist, get))

# Delete single track files from environment -----> is this needed?
rm(list= dflist)

# Converting the df to sf object
library(sf)
all_tracks <- st_as_sf(all_tracks, coords = c("lon", "lat"), crs = 4326)
str(all_tracks)

# Transforming the crs to CH1903 +LV95 or EPSG:2056 & Timezone
all_tracks <- st_transform(all_tracks, 2056)
str(all_tracks)
# Check Timezone
attr(all_tracks$timestamp, "tzone")

#  Filtering out old data
all_tracks <- all_tracks |> 
  mutate("year" = year(timestamp)) |> #for this use library lubridate
  filter(year == 2024)

#Specify trajectory IDs
#To differentiate between the different records, we assign an ID. 
#This is also to ensure that if there were tracks with the same name, their fixes are not combined. 
## Create function
rle_id <- function(vec) {
  x <- rle(vec)$lengths
  as.factor(rep(seq_along(x), times = x))
}
## Apply function to run along record_names
all_tracks <- all_tracks |>
  mutate(trajID = rle_id(rec_id))
summary(all_tracks)

# choose exemplary trajectories (of mixed movement)  
trajIDs <- c(1, 3) 
selected_tracks <- all_tracks |> 
  filter(trajID %in% trajIDs)
#now, we just have the tracks that interest us


#### calculation of parameters ####

# Distance Function
distance_by_element <- function(later, now) {
  as.numeric(
    st_distance(later, now, by_element = TRUE)
  )
}
# Movement Parameters Calculation
selected_tracks <- selected_tracks |> 
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



##### NA omit and Drop Geom  #####
# filter out all values with NA 
selected_tracks_na_omit <- na.omit(selected_tracks)

# filter out selected values and geometry for cluster analysis (important to first NA omit, then  drop geometry)
km_no_geom <- selected_tracks_na_omit |> 
  select(distance, speed, acceleration, avg_speed_10s, avg_speed_60s, avg_acc_10s, avg_acc_60s, el_change, d_direct10, d_sinu10,  sinuosity) |> 
  st_drop_geometry()
#scale the values 
km_all_scaled <- km_no_geom %>%
  scale()

##### Classification with speed  #####

selected_tracks_na_omit  <- selected_tracks_na_omit  |>
  mutate(speed_cluster = case_when(
    speed_kmh == 0 ~ "1", #standing
    speed_kmh < 5 ~ "2", #walking
    speed_kmh >= 5 & speed_kmh < 18 ~ "3",  #running
    speed_kmh >= 18 & speed_kmh < 30 ~ "4", # biking 
    speed_kmh > 30 ~ "5" # tram 
    ),
    speed_cluster_name = case_when(
      speed_cluster == 1 ~ "standing",
      speed_cluster == 2 ~ "walking",
      speed_cluster == 3 ~ "running",
      speed_cluster == 4 ~ "biking",
      speed_cluster == 5 ~ "tram"
    )
    ) 


##### LEAVE OUT transformation of unevenness in the manual clustering (like rID segmentation) #####

"selected_tracks_na_omit <- selected_tracks_na_omit  |> 
  mutate(
    transformed_values = slide_dbl(
      as.numeric(speed_cluster),
      ~ ifelse(
        .x != lag(.x, default = .x[1]) & .x != mode(.x),
        1,
        .x
      ),
      before = 5,
      after = 5,
      .complete = TRUE
    )
  )"



##### Classification with GIS   #####
# export (preliminary table with just one track) to define cluster in GIS 
coords <- st_coordinates(selected_tracks_na_omit)

# Add x and y columns to the sf object
selected_tracks_na_omit$x <- coords[,1]
selected_tracks_na_omit$y <- coords[,2]
selected_tracks_na_omit |> 
  write_csv( file = "data/traj1_traj3")
#was done in ArcGIS, and CSV was reimported. 
traj1_traj3_mit_Zuordnung <- read_csv("traj1_traj3_mit_Zuordnung.csv")

# Add the GIS class to the original data frame
selected_tracks_na_omit<- cbind(selected_tracks_na_omit, GIS_name = traj1_traj3_mit_Zuordnung$GIS_Group) 

#assign values according to the ones in speed classification
selected_tracks_na_omit <- selected_tracks_na_omit |> 
  mutate(GIS_number = case_when(
    GIS_name == "standing" ~ "1",
    GIS_name == "walking" ~ "2",
    GIS_name == "running" ~ "3",
    GIS_name == "biking" ~ "4",
    GIS_name == "tram" ~ "5",
  ))

#### k-means Analysis #### 

##### Find the right amount of clusters #####
#(several intents, with elevation and sinuosity and without, but it always gets to 2 -3 clusters only. )

plot_k_elbow <- fviz_nbclust(km_all_scaled, kmeans, method = "wss") #takes 3 mins to calculate, gives 5 clusters

# cascade method
KM.cascade <- cascadeKM(km_all_scaled,  inf.gr = 2, sup.gr = 8, iter = 100, criterion = "ssi")
summary(KM.cascade)
cascade_results <- KM.cascade$results #SSI 


##### apply k means #####
set.seed(1)
km_2 <- kmeans(km_all_scaled, 2)
km_4 <- kmeans(km_all_scaled, 4)
km_5 <- kmeans(km_all_scaled, 5)

#  running k-means multiple times with different random starts (specified by the nstart parameter) and choosing the best result helps avoid getting stuck in a poor local optimum. 
km_5_100 <- kmeans(km_all_scaled, 5, nstart = 100)
km_5_20 <- kmeans(km_all_scaled, 5, nstart = 20)

# Match cluster IDs
# install.packages("clue")
# library(clue)
# km_5_100$cluster <- cl_predict(clue::cl_ensemble(km_5, km_5_100), km_all_scaled, method = "mean")

#plots for the cluster distribution
plot_cluster_4 <- fviz_cluster(km_4, data = km_all_scaled)

plot_cluster_5 <- fviz_cluster(km_5, data = km_all_scaled)+
  ggtitle("Cluster k=5 no n defined")

plot_cluster_5_20 <- fviz_cluster(km_5_20, data = km_all_scaled)+
  ggtitle("Cluster k=5 n=20")

plot_cluster_5_100 <- fviz_cluster(km_5_100, data = km_all_scaled)+
  ggtitle("Cluster k=5 n=100")


#  Add the k clusters to the original data frame
selected_tracks_na_omit<- cbind(selected_tracks_na_omit, kmeans4 = km_4$cluster) 
selected_tracks_na_omit<- cbind(selected_tracks_na_omit, kmeans5 = km_5$cluster) 
selected_tracks_na_omit<- cbind(selected_tracks_na_omit, kmeans5_20 = km_5_20$cluster) 
selected_tracks_na_omit<- cbind(selected_tracks_na_omit, kmeans5_100 = km_5_100$cluster) 
# we dont include k=2, as it does not make sense. 

#### h means Analysis ####
hm_all_scaled <- km_no_geom %>%
  scale()

# Compute the distance matrix
dist_matrix <- dist(hm_all_scaled)

# Perform hierarchical clustering hmeans
set.seed(1)

hc_ward <- hclust(dist_matrix, method = "ward.D")
hc_single <- hclust(dist_matrix, method = "single")
hc_complete <- hclust(dist_matrix, method = "complete")

# Cut the tree into a desired number of clusters (5 clusters)
clust_ward_5 <- cutree(hc_ward, k = 5)
clust_single_5 <- cutree(hc_single, k = 5)
clust_complete_5 <- cutree(hc_complete, k = 5)
#complete and single do not make appropriate assignation of datapoints to clusters as they are chaining. ALso visible in summary.

# Add the clusters to the original data frame
selected_tracks_na_omit$c_single_5<- as.factor(clust_single_5)
selected_tracks_na_omit$c_compl_5<- as.factor(clust_complete_5)
selected_tracks_na_omit$c_ward_5<- as.factor(clust_ward_5)

# Distribution of points among clusters
single_5 <- summary(selected_tracks_na_omit$c_single_5)
complete_5 <- summary(selected_tracks_na_omit$c_compl_5)
ward_5 <- summary(selected_tracks_na_omit$c_ward_5)
# we wont take into consideration single and complete, as the cluster distribution is not suitable (see chaining).

summary_table_hclust <- data.frame(
  single = single, complete = complete, ward = ward) |> 
  t() |>  as.data.frame() # transpose the data so that columns become rows.

# How individual points are distributed on track 
ward_plot_5 <- plot(clust_ward_5, main = "Ward")

# Dendrogramm of cluster result
par(mfrow = c(1, 3))
plot(hc_single, main = "Single", labels = NULL, sub = NULL)
plot(hc_complete, , main = "Complete")
plot(hc_ward, main = "Ward")

# plot results
tmap_mode("plot")
P_ward_5<- selected_tracks_na_omit |> 
  tm_shape() +
  tm_dots(size = 0.06, col = "c_ward_5") 
# fast to compute, good differentiation

#### Output Maps ####

tmap_mode("plot")


trackID_map <- tm_shape(osm_bg) +
  tm_rgb(alpha = 0.4)+
  tm_shape(selected_tracks_na_omit) + 
  tm_dots(col = "trajID", palette = "Paired", alpha = 1)


speed_map <- tm_shape(selected_tracks_na_omit)+
  tm_dots(col = "speed_kmh", palette = "-RdYlGn") + #das minus vor der Palette invertiert den normalen Farbverlauf
  tm_view(set.view = c(8.520515, 47.388322,  16))


#speed parameter  classification
cluster_speed_map <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "speed_cluster_name", palette = "Paired")+ 
  tm_view(set.view = c(8.520515, 47.388322,  16))

# smoothed speed parameter (transformed value creation is not run/evaluated above..)
# selected_tracks_na_omit <- selected_tracks_na_omit %>% mutate(transformed_values_char = as.character(transformed_values))
# cluster_smoothed_map <- tm_shape(selected_tracks_na_omit)+ tm_dots(col = "transformed_values_char", palette = "RdYlGn")

# GIS map 
cluster_GIS_map <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "GIS_name", palette = "Paired")+
  tm_view(set.view = c(8.520515, 47.388322,  16))

# k means maps
cluster_k5_map <- tm_shape(osm_bg) +
  tm_rgb(alpha = 0.4)+
  tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "kmeans5", palette = "Paired")

selected_tracks_na_omit <- selected_tracks_na_omit |> 
  mutate(k5_names  = case_when(
    kmeans5 == "1" ~ "walking",
    kmeans5 == "2" ~ "running",
    kmeans5 == "3" ~ "biking",
    kmeans5 == "4" ~ "standing",
    kmeans5 == "5" ~ "undefined",
         ))

cluster_k5names_map <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "k5_names", palette = "Paired")

cluster_k5_20_map <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "kmeans5_20", palette = "Paired")

cluster_k5_100_map <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "kmeans5_100", palette = "Paired")

cluster_k4_map <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "kmeans4", palette = "Paired")

# h means maps
cluster_h4_ward <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "c_ward_4", palette = "RdYlGn")

cluster_h5_ward <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "c_ward_5", palette = "RdYlGn")

selected_tracks_na_omit <- selected_tracks_na_omit |> 
  mutate(hward_names  = case_when(
    c_ward_5 == "1" ~ "running",
    c_ward_5 == "2" ~ "undefined",
    c_ward_5 == "3" ~ "biking/tram",
    c_ward_5 == "4" ~ "walking",
    c_ward_5 == "5" ~ "standing",
  ))
cluster_h5_names_map <- tm_shape(selected_tracks_na_omit)+ 
  tm_dots(col = "hward_names", palette = "Paired")
tmap_arrange(cluster_k5names_map, cluster_h5_names_map, cluster_GIS_map)


#### Verification #####

##### Chi square #####
# list of tables to compare
tables_list <- list(
  GIS_speed = table(selected_tracks_na_omit$speed_cluster, selected_tracks_na_omit$GIS_number),
  GIS_kmeans = table(selected_tracks_na_omit$GIS_number, selected_tracks_na_omit$kmeans5),
  GIS_hmeans = table(selected_tracks_na_omit$GIS_number, selected_tracks_na_omit$c_ward_5),
  speed_hmeans = table(selected_tracks_na_omit$speed_cluster, selected_tracks_na_omit$c_ward_5),
  speed_kmeans = table(selected_tracks_na_omit$speed_cluster, selected_tracks_na_omit$kmeans5),
  hmeans_kmeans = table(selected_tracks_na_omit$c_ward_5, selected_tracks_na_omit$kmeans5)
)

# Funktion zum Durchführen des Chi-Quadrat-Tests
perform_chisq_test <- function(tbl) {
  chisq.test(tbl)
}

# Chi-Quadrat-Tests für alle Tabellen durchführen
chi_tests <- lapply(tables_list, perform_chisq_test)

# Ergebnisse anzeigen
chi_tests

# extract values from chi_tests
extract_chisq_results <- function(test_result) {
  c(X_squared = test_result$statistic,
    df = test_result$parameter,
    p_value = test_result$p.value)
}
results_df <- as.data.frame(do.call(rbind, lapply(chi_tests, extract_chisq_results)))


#alte, unnötige
table_man_k4 <- table(selected_tracks_na_omit$speed_cluster, selected_tracks_na_omit$kmeans4)
table_ward_h4 <- table(selected_tracks_na_omit$speed_cluster, selected_tracks_na_omit$c_ward_4)
table_single_h4 <- table(selected_tracks_na_omit$speed_cluster, selected_tracks_na_omit$c_single_4)

# Chi-Quadrat-Test

chi_man_k4 <- chisq.test(table_man_k4)
chi_ward_h4 <- chisq.test(table_ward_h4)
chi_single_h4 <- chisq.test(table_single_h4)
# --> we always can only compare one clustering method with one other.
# --> all of the tests have a sign. lower than 0.05, so it doesnt serve our purpose really?

# FISHERS TEST
only_clusters <- selected_tracks_na_omit |> 
  dplyr::select(speed_cluster, GIS_number,  kmeans4, kmeans5, kmeans5_100, c_ward_4, c_ward_5) |> 
  st_drop_geometry()


#fisher.test(only_clusters)


##### kappa coeficient  #####




##### corr test #####


#cor.test(selected_tracks_na_omit$clusterGIS, df$clusterk, method = "pearson") # this one not, as it as linearity as condition
cor.test(as.numeric(selected_tracks_na_omit$speed_cluster), as.numeric(selected_tracks_na_omit$kmeans4),  method = "spearman") 

class(selected_tracks_na_omit$speed_cluster)

#cor.test(as.numeric(selected_tracks_na_omit$clusterGIS), as.numeric(selected_tracks_na_omit$clusterk),method = "kendall")


##### save the image of everything #####

# save(selected_tracks,file="selected_tracks.rda") -> dont need

save.image("my_environment.rdata") #speichert das gesamte environment ab
# den generierten File muss man in gitignore mit reinnehmen, da er meist zu gross ist für github






#### Other functions #####

# Function hcoplot(): (from Research Methods)
# Reorder and plot dendrogram with colors for groups and legend
# Usage: hcoplot(tree = hclust.object, diss = dissimilarity.matrix, k = nb.clusters, 
#	title = paste("Reordered dendrogram from",deparse(tree$call),sep="\n"))
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