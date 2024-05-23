# Proposal for Semester Project

<!-- 
Please render a pdf version of this Markdown document with the command below (in your bash terminal) and push this file to Github

quarto render Readme.md --to pdf
-->

**Patterns & Trends in Environmental Data / Computational Movement
Analysis Geo 880**

| Semester:      | FS24                                     |
|:---------------|:---------------------------------------- |
| **Data:**      | Laura & Lucia Strava Data  |
| **Title:**     | Comparing Student Movement Patterns        |
| **Student 1:** | Laura Vetter                        |
| **Student 2:** | Lucia Scheele                        |

List template: https://www.w3schools.com/html/html_headings.asp
<ol>
  <li></li>
  <li> </li>  
  <li> </li>
</ol>

## Abstract 
<!-- (50-60 words) -->
"using an unlabeled dataset to obtain mode detection with high accuracy in a transport complex urban environment is challenging" (Lin 2013). 
using unsupervised learning algorithm to identify transport modes. 

## Research Questions
<!-- (50-60 words) -->
<ol>
  <li> Transport mode detection:
What kind of transport was used during a certain trajectory and how many different transport types can be detected in 1) within one trajectory and 2) between trajectories?

(source: Sadeghian 2022) to find on 17.05 moodle 
</li>
  <li> How do Lauras running trips vary from each other in speed and acceleration? 
Using similarity Measures (Frechet, DTW etc) on running data by Laura (temporally variable but spatially similar) 
</li>  
  <li> What patterns can we detect in the bike riding data of two individuals? Is it possible to detect which trajectory was done by which person?   (stichwort: "ignoring red lights on the bike" - detecting acceleration patterns in bike trajectories
 </li>
</ol>



## Expected Results / products
<!-- What do you expect, anticipate? -->

1) Transport mode detection:
    5 k means classification of movement 

2) Running Trajectories from the same route but at different times are expected to be relatively similar 

3) cycling trajectories from different routes are expected to be dissimilar, but cycling speed and acceleration patterns between individuals are expected to be more dissimilar. 





## Data
<!-- What data will you use? Will you require additional context data? Where do you get this data from? Do you already have all the data? -->
Movement data collected strava by Laura, Lucia gathered over a timespan of April - May 2024. 
17 Trips + 14 Trips 
with movement types Car, Train, Tram, Bike, Run, Walk 

Additional Data:
  - Metadata Strava (Activity Types) & individual knowledge about trips
  - traffic infrastructure data by city of zurich ( https://www.stadt-zuerich.ch/geodaten/ ) 


## Analytical concepts
Which analytical concepts will you use? 
<ol>
  <li>Scale & Granularity: 
  Bc of very different movement types, different scales will be needed. 
</li>
  <li> Discrete data, as strava collects point data for every second. 
</li>  
  <li> Relative in space & time, only the running data has similar spatial data, but is not completely the same </li>
   <li> parameters to assess similarity & to cluster trajectories: average speed, average acceleration, maximum and minimum speed, acceleration during each segment, segment distance. Maybe direction, duration, azimuth, sinuosity? 
   </li> 
   <li>concepts to clarify:  limited, constrained - do these play a role?
</li>
</ol>


What conceptual movement spaces and respective modelling approaches of trajectories will you be using? 
<ol>
  <li>segmentation: trips are segmented according to the speed into
     activity type
    stationary vs moving </li>
  <li> and then use an unsupervosed learning algorithm to cluster  (probably k Means)/li>
  <li>
similarity:  similarity of trips will be calculated using different similarity measures (DTW, EditDist, Frechet, LCSS)
</li>
</ol>

<h3>Other info</h3>
  "The K- means algorithm is the most common in non-hierarchical clustering methods" (Bachir et al., 2018) 
    "By reducing the number of K, the performance of K-means was improved" (Sadeghian 2020)

  We could use k=4: train/tram, walking, running, cycling 
  Segment-wise analysis of k-means, not trip wise!
  Analysis: define different characteristics for movement types e.g. walking segments: 
    <ol>
  <li>longer than 60 seconds</li>
  <li>average speed not faster than 6 km/h</li>
  <li>maximum speed should not be greater than 12 km/h (otherwise running)
    </li>
</ol>
then, probably some data is directly classified into one class, but some can be   "multiclassfied". these are given into the GIS analysis with the transport infrastructure data



What additional spatial analysis methods will you be using? 
xxx

## R concepts
<!-- Which R concepts, functions, packages will you mainly use. What additional spatial analysis methods will you be using? -->
Working with time: library(lubridate)
Visualisation: library(tmap)
Similarity measures: library(similaritymeasures)
K-means: library(??)

for segmentation, no R package is needed?





## Risk analysis
<!-- What could be the biggest challenges/problems you might face? What is your plan B? -->
- Outliers/ NO DATA  bc of missing GPS signal in tunnels f.ex. 
- variability of the data due to different transport modes during one trajectory (but thats the whole point)
- recording frequency variablity (14, 17 trips is not a high sampling rate)
- similarity/clustering may take a long computing time

## Questions? 
<!-- Which questions would you like to discuss at the coaching session? -->
If we want to make a "red light ignoring"-Analysis, ow to define crossroads (=turning points)? Same as "static" definition ? Or somehow via GIS/additional data?

Did we use moving average/smoothing algorithms already?  Chat GTP suggests we should do that for the segmentation
