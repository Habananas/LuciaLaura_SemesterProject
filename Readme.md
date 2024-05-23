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

## Abstract 
<!-- (50-60 words) -->
"using an unlabeled dataset to obtain mode detection with high accuracy in a transport complex urban environment is challenging" (Lin 2013). 
using unsupervised learning algorithm to identify transport modes. 

## Research Questions
<!-- (50-60 words) -->

1. Transport mode detection  ... (Sadeghian)
  - within one trajectory 
  - intertrajectoric measures  
    (source: Sadeghian 2022) to find on 17.05 moodle https://moodle.zhaw.ch/pluginfile.php/1731463/mod_resource/content/1/SadegianEtal_TravBehavSoc_2022.pdf 

2. "ignoring red lights on the bike" - detecting acceleration patterns in bike trajectories
(infrastructure data: )

3. running data - similarity measures (temporal variability, but spatial similarity) & when did I start walking?


## Expected Results / products
<!-- What do you expect, anticipate? -->

5 k means classification of movement 

cycling trajectories from different routes are expected to be dissimilar. 
Running Trajectories from the same route but at different times are expected to be relatively similar 



## Data
<!-- What data will you use? Will you require additional context data? Where do you get this data from? Do you already have all the data? -->
Movement data collected strava by Laura, Lucia gathered over a timespan of April - May 2024. 
| File  | Laura   | Lucia |
| -------- | ------- |
| timespan  | April - May 2024    |April - May 2024    |

do we have control mechanism/ground truth data? 
  intertrajetorical data:
  - own knowledge
  - infrastructure data 
  within trajectory:
  - SBB data 
  - infrastructure data 


Meta data of trajectories 
Infrastructure data 
SBB data 

## Analytical concepts
Which analytical concepts will you use? 

choosing a scale -  bc of different transport types, different granularities might needed 
space & time as a relative measure
continuous, limited, constrained,
parameters to assess similarity & cluster trajectories: speed, acceleration, azimuth, sinuosity 


What conceptual movement spaces and respective modelling approaches of trajectories will you be using? 
segmentation: trips are segmented according to the speed into
- activity type
- stationary vs moving 

(considering average speed, average acceleration, maximum and minimum speed, acceleration during each segment, segment distance, direction, and duration) 

similarity: 
similarity of trips will be calculated using different similarity measures (DTW, EditDist, Frechet, LCSS)


What additional spatial analysis methods will you be using? 
xxx

## R concepts
<!-- Which R concepts, functions, packages will you mainly use. What additional spatial analysis methods will you be using? -->
lubridate 
tmap
similaritymeasures

for segmentation, no R package is needed

will we do Unsupervised learning (K means) ? The K- means algorithm is the most common in non-hierarchical clustering methods (Bachir et al., 2018) By reducing the number of K, the performance of K-means was improved
We could use k=4: train/tram, walking, running, cycling 
Segment-wise analysis of k-means, not trip wise!
put requirements for k (but isnt that superwised then, already?) e.g. for walking segment: 
 - longer than 60 seconds
 - average speed not faster than 6 km/h
 - maximum speed should not be greater than 12 km/h (otherwise running)
 
then, probably some data is directly classified into 1 class, but some can be multiclassfied. 
these are given into the GIS analysis -  segments are joined with the transport network 




## Risk analysis
<!-- What could be the biggest challenges/problems you might face? What is your plan B? -->
Outliers bc of missing GPS 
variability of the data due to different transport modes during one trajectory
recording frequency variablity (7 agains 20), laura low variability of data (2 running traj and 3 train tracks)
similarity/clustering may take a long computing time
## Questions? 
<!-- Which questions would you like to discuss at the coaching session? -->
If we want to make a "red light ignoring"-Analysis, ow to define crossroads (=turning points)? Same as "static" definition ? Or somehow via GIS/additional data?
