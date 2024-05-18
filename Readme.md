# Proposal for Semester Project

26th iof May hand in
<!-- 
Please render a pdf version of this Markdown document with the command below (in your bash terminal) and push this file to Github

quarto render Readme.md --to pdf
-->

**Patterns & Trends in Environmental Data / Computational Movement
Analysis Geo 880**

| Semester:      | FS24                                     |
|:---------------|:---------------------------------------- |
| **Data:**      | Strava Data Project (or other, yet to be defined)  |
| **Title:**     | We need a better title               |
| **Student 1:** | Laura Vetter                        |
| **Student 2:** | Lucia Scheele                        |

## Abstract 
<!-- (50-60 words) -->
Up to now, we just have the strava data that I uploaded, maybe you, Lucia have more ideas?

## Research Questions
<!-- (50-60 words) -->

transport mode detection
  - within one trajectory 
  - intertrajectoric measures  
    (source: Sadeghian 2022) to find on 17.05 moodle https://moodle.zhaw.ch/pluginfile.php/1731463/mod_resource/content/1/SadegianEtal_TravBehavSoc_2022.pdf 

at what times do we go for a run/ use the bike/ train? is there a pattern?



## Expected Results / products
<!-- What do you expect, anticipate? -->

## Data
<!-- What data will you use? Will you require additional context data? Where do you get this data from? Do you already have all the data? -->
Movement data collected strava by Laura, Lucia gathered over a timespan of April - May 2024. 
| File  | Laura   | Lucia |
| -------- | ------- |
| timespan  | April - May 2024    |April - May 2024    |

do we have control mechanism/ground truth data? 
  intertrajetorical data:
  - own knowledge
  - infrastructuredata 
  within trajectory:
  - SBB data 
  - infrastructure data 


Meta data of trajectories 
Street data 
SBB data 

## Analytical concepts
Which analytical concepts will you use? 
choosing a scale -  bc of different transport types, different granularities might needed 
space & time as a relative measure
continuous, limited, constrained,
parameters to assess similarity & cluster trajectories: speed, acceleration, azimuth, sinuosity 
similarity & segmentation

What conceptual movement spaces and respective modelling approaches of trajectories will you be using? 

What additional spatial analysis methods will you be using? 

## R concepts
<!-- Which R concepts, functions, packages will you mainly use. What additional spatial analysis methods will you be using? -->


Unsupervised learning (K means) - 


## Risk analysis
<!-- What could be the biggest challenges/problems you might face? What is your plan B? -->
Outliers bc of missing GPS 
variability of the data due to different transport modes during one trajectory
recording frequency variablity (7 agains 20), laura low variability of data (2 running traj and 3 train tracks)

similarity/clustering may take a long computing time
## Questions? 
<!-- Which questions would you like to discuss at the coaching session? -->

