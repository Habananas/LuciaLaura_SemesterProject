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

# choose exemplary trajectories (of mixed movement)  (or not, if we already did in before step)
trajIDs <- c(1, 3) #now, we just have the tracks that interest us, therefore we just select all.

selected_tracks <- all_tracks |> 
  filter(trajID %in% trajIDs)


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

##### manual clustering with speed  #####

selected_tracks  <- selected_tracks  |>
  mutate(manual_cluster = case_when(
    speed_kmh == 0 ~ "1", #standing
    speed_kmh < 5 ~ "2", #walking
    speed_kmh >= 5 & speed_kmh < 18 ~ "3",  #running
    speed_kmh >= 18 & speed_kmh >= 30 ~ "4", # velo 
    speed_kmh < 30 ~ "5" # tram
  ))

##### transformation of unevenness in the manual clustering  #####

selected_tracks <- selected_tracks  |> 
  mutate(
    transformed_values = slide_dbl(
     as.numeric(manual_cluster),
      ~ ifelse(
        .x != lag(.x, default = .x[1]) & .x != mode(.x),
        1,
        .x
      ),
      before = 5,
      after = 5,
      .complete = TRUE
    )
  )


#### k-means Analysis #### 

##### data prep & partitioning #####

selected_tracks_na_omit <- na.omit(selected_tracks)

# we dont need this for now
"without direct & dsinu
    km_no_sinu_geom <- selected_tracks_na_omit |> 
      dplyr::select(distance, time_diff, speed, acceleration, avg_speed_10s, avg_speed_60s, avg_acc_10s, avg_acc_60s, el_change)
    
    km_no_sinu<- km_no_sinu_geom |> 
      st_drop_geometry()"

"selection of the needed criteria and drop of geometry "
km_all_geom <- selected_tracks_na_omit |> 
  select(distance, time_diff, speed, acceleration, avg_speed_10s, avg_speed_60s, avg_acc_10s, avg_acc_60s, el_change, d_direct10, d_sinu10,  sinuosity) |> 
  na.omit() |> 
  st_drop_geometry()
#  Important, first NA omit, then  drop geometry, damit später wieder zusammenführbar!geometry column has to go away, otherwise fviz not work

km_all_scaled <- km_all_geom %>%
  scale()


##### Find the right amount of clusters #####

# elbow method 
plot_k_elbow <- fviz_nbclust(km_all_scaled, kmeans, method = "wss") #takes 3 mins to calculate, gives 5 clusters
#interesting: the "elbow"/knick, which indicates the appropriate k value, changes when we add sinuosity parameter from 5 to 4. So we try k means with both k values!

# cascade method
KM.cascade <- cascadeKM(km_all_scaled,  inf.gr = 2, sup.gr = 5, iter = 100, criterion = "ssi")
summary(KM.cascade)
cascade_results <- KM.cascade$results #SSI 
cascade_results 




##### apply k means #####
set.seed(1)
km_4 <- kmeans(km_all_scaled, 4)
km_5 <- kmeans(km_all_scaled, 5)

# bind cluster outputs to the initial table 
selected_tracks_na_omit<- cbind(selected_tracks_na_omit, kmeans4 = km_4$cluster) 
selected_tracks_na_omit<- cbind(selected_tracks_na_omit, kmeans5 = km_5$cluster) 


#### h means analysis ####
hm_all_scaled <- km_all_geom %>%
  scale()

# Compute the distance matrix
dist_matrix <- dist(hm_all_scaled)
#dist_matrix

# Perform hierarchical clustering of different type
set.seed(1)

hc_single <- hclust(dist_matrix, method = "single")
hc_ward <- hclust(dist_matrix, method = "ward.D")
hc_complete <- hclust(dist_matrix, method = "complete")

# Cut the tree into a desired number of clusters (e.g., 4 clusters)
clust_ward_4 <- cutree(hc_ward, k = 4)
clust_single_4 <- cutree(hc_single, k = 4)
clust_complete_4 <- cutree(hc_complete, k = 4)

# Add the clusters to the original data frame
selected_tracks_na_omit$c_ward_4<- as.factor(clust_ward_4)
selected_tracks_na_omit$c_single_4<- as.factor(clust_single_4)
selected_tracks_na_omit$c_compl_4<- as.factor(clust_complete_4)

# Distribution of points among clusters
summary(selected_tracks_na_omit$c_ward_4)
summary(selected_tracks_na_omit$c_single_4)
summary(selected_tracks_na_omit$c_compl_4)
# we wont take into consideration single and complete, as the cluster distribution is not suitable (see chaining).


# export (preliminary table with just one track) to define cluster in GIS 
coords <- st_coordinates(selected_tracks_na_omit)

# Add x and y columns to the sf object
selected_tracks_na_omit$x <- coords[,1]
selected_tracks_na_omit$y <- coords[,2]

 selected_tracks_na_omit |> 
  filter(trajID == 3) |> 
   write_csv( file = "data/traj3Laura_cluster")



# Track split into 5 clusters... 
ward_plot <- plot(clust_ward_4, main = "Ward")

# Dendrogramm of cluster result
ward_dendro <- plot(hc_ward, main = "Ward") # hat komischen schwarzen Balken unten (labels??)

# plot results
P_ward_4<- selected_tracks_na_omit |> 
  tm_shape() +
  tm_dots(size = 0.05, col = "c_ward_4") 
# fast to compute, good differentiation


#### Verification #####
kappa 
##### kappa coeficient ? ANOVA? CHI SQUARE7fisher test? RANKSUM? #####
# kappa didnt work. 
# rank sum is for ordinal, ois not ordinal. 

# chi square is for two or more  independent nominal groups - is this the case?
#chat gpt Chi square example: 
# Erstellen einer Beispiel-Datenrahmen
set.seed(123)
Cluster1 <- sample(1:5, 100, replace = TRUE)
Cluster2 <- sample(1:5, 100, replace = TRUE)
Cluster3 <- sample(1:5, 100, replace = TRUE)
df <- data.frame(Cluster1, Cluster2, Cluster3)

# Erstellen einer Kontingenztabelle
table_12 <- table(df$Cluster1, df$Cluster2)
table_13 <- table(df$Cluster1, df$Cluster3)
table_23 <- table(df$Cluster2, df$Cluster3)

table_man_k4 <- table(selected_tracks_na_omit$manual_cluster, selected_tracks_na_omit$kmeans4)
table_ward_h4 <- table(selected_tracks_na_omit$manual_cluster, selected_tracks_na_omit$c_ward_4)
table_single_h4 <- table(selected_tracks_na_omit$manual_cluster, selected_tracks_na_omit$c_single_4)

# Chi-Quadrat-Test
chi_12 <- chisq.test(table_12)
chi_13 <- chisq.test(table_13)
chi_23 <- chisq.test(table_23)

chi_man_k4 <- chisq.test(table_man_k4)
chi_ward_h4 <- chisq.test(table_ward_h4)
chi_single_h4 <- chisq.test(table_single_h4)
# --> we always can only compare one clustering method with one other.
# --> all of the tests have a sign. lower than 0.05, so it doesnt serve our purpose really?

# FISHERS TEST
only_clusters <- selected_tracks_na_omit |> 
  dplyr::select(manual_cluster, kmeans4, kmeans5) |> 
  st_drop_geometry()
  

fisher.test(only_clusters)

##### corr test #####


#cor.test(selected_tracks_na_omit$clusterGIS, df$clusterk, method = "pearson") # this one not, as it as linearity as condition
cor.test(as.numeric(selected_tracks_na_omit$manual_cluster), as.numeric(selected_tracks_na_omit$kmeans4),  method = "spearman") 

class(selected_tracks_na_omit$manual_cluster)

cor.test(selected_tracks_na_omit$clusterGIS, selected_tracks_na_omit$clusterk,method = "kendall")

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
