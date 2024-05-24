---
editor_options: 
  markdown: 
    wrap: 72
---

# Proposal for Semester Project

```{=html}
<!-- 
Please render a pdf version of this Markdown document with the command below (in your bash terminal) and push this file to Github

quarto render Readme.md --to pdf
-->
```
**Patterns & Trends in Environmental Data / Computational Movement
Analysis Geo 880**

| Semester:      | FS24                                                                                           |
|:---------------|:-----------------------------------------------------------------------------------------------|
| **Data:**      | Laura & Lucia Strava Data                                                                      |
| **Title:**     | Movement type detection - the potential of cluster and similarity analysis in low quality data |
| **Student 1:** | Laura Vetter                                                                                   |
| **Student 2:** | Lucia Scheele                                                                                  |

List template: <https://www.w3schools.com/html/html_headings.asp>

## Abstract

As we tried to think of possible project ideas for our semester project,
the quality of our data and the accuracy of the given meta data
confronted us with major limitations. As this seems to be a common
problem for trajectory research, we will try to solve this hurdle on a
computational basis. Methods applied include segmentation, k-means
clustering and similarity analysis.  

## Research Questions

<ol>

<li>Between which movement types can we differentiate in a collection of
trajectories specifically (a) within one trajectory and (b) between
different trajectories using segmentation and clustering?</li>

<li>What patterns can we detect in the resulting bike riding data of two
individuals? Is it possible to detect which trajectory was done by which
person?</li>

 

<li>How can movement data with similar spatial but varying time
parameters be analyzed with the common similarity measures (DTW, FD,
EDR, LCSS)?</li>

<ol>

## Data

<!-- What data will you use? Will you require additional context data? Where do you get this data from? Do you already have all the data? -->

The data sample consists of movement data collected with the Tracking
App STRAVA, by two individuals over a timespan of April - May 2024.
Overall, 31 trips were recorded (17 Trips + 14 Trips per individual)
with the movement types walking, running, cycling, bus, tram, train and
car. Data points were recorded every second, resulting in a high
resolution. However, data frequency might not be consistent in all cases
due to lack of signal (e.g. in a train).  

Additional data that might be used for the analysis include metadata
from Strava, individual knowledge about trips and traffic infrastructure
data by the city of Zurich ( <https://www.stadt-zuerich.ch/geodaten/> ).
While the metadata from Strava does supply movement type information, it
is to be noted that this data is not accurate in all cases. For example,
a track was recorded as a travel by train but includes the walk or bike
to the train station. In these cases, the personal knowledge of the
trips provides an important addition.  

## Analytical concepts

<u>Conceptual movement spaces and modelling approaches</u>

In Strava, a point with location and timestamp is created by default
every second (if the signal allows for it), it is therefore a discrete
dataset with a relatively high resolution. The scale at which the
spatial data is analyzed is important, as derived movement parameters
(e.g. speed, step length or turning angle) are strongly influenced by it
(Laube, How fast is a cow 2011). This must be considered when conducting
analysis for the different movement types. Concerning the cluster
analysis, space and time of trajectories will be treated to be relative.
For the similarity analysis of a repeated running track, the spatial
data is similar and will thus be treated as absolute.  

The parameters to cluster and to assess similarity of the trajectories
will be the following: 

-   Average, maximum and minimum speed 

-   average acceleration and acceleration during each segment 

-   segment distance 

-   Possibly: direction, duration, azimuth and sinuosity 

Segmentation 

Since some trajectories include several movement types, we will apply
two types of trajectory segmentation, using the above-mentioned
parameters.  

In the first step, segmentations will be conducted by considering the
static points (i.e. using the stepMean function developed in class). For
cases where different movement types cannot be seperated by static
points (i.e. changing from walking to running), segmentations will be
achieved with the different characteristics of the respective movement.
The parameters for the walking segments could be: 

-   Treshhold: longer than 60 seconds 

-   average speed not faster than 6 km/h 

-   maximum speed should not be greater than 12 km/h (otherwise
    running) 

If time and resources allow it, an unsupervised learning algorithm
(k-means, as it is the most common in non-hierarchical clustering
methods (Bachir et al., 2018)) will be applied to cluster segments
within and between trajectories. The wuality of this analysis will then
be assessed by comparing the results with the STRAVA metadata and our
personal track knowledge.  \
By reducing the number of k, Sadeghian et. Al. (2020) could improve the
performance of the k-means method. Therefore, this analysis will explore
different k-values (i.e. 7,5,4) and, if necessary, reduce the number of
distinct movement types. 

In result, some data is directly classified into one class, whereas some
can be "multiclassfied", meaning it could belong to e.g. running or
walking. Some segments might also be wrongly classified (e.g. train
stops).  Again, if time and resources allow for it, these multi-class
segments are compared with transport infrastructure data. If the
negative acceleration (stopping) of a segment happens in the defined
range of a train station, it could thereby still be classified as a
movement by train. Meanwhile, we must be careful to not to classify
running segments as an incoming train!  

Similarity 

Concerning a homogenous subset of data where the same route was used
several times, four tracked trajectories will be compared using
different similarity measures (DTW, EditDist, Frechet, LCSS). The
objective is to evaluate how well each similarity measure predicts the
speed and spatial differences of the trajectories. 

## R concepts

<!-- Which R concepts, functions, packages will you mainly use. What additional spatial analysis methods will you be using? -->

The typical ones for preprocessing\
- readr, dplyr,

Working with time: library(lubridate)\
Visualisation: library(tmap)\
Similarity measures: library(similaritymeasures) K-means: library(??)

for segmentation, no R package is needed?

## Expected Results / products

According to the activities during which we recorded our strava tracks,
we expect to find the several groups of movement types. The number of
groups will vary with the scale that we apply during the analysis.

When

1)  Running Trajectories from the same route but at different times are
    expected to be relatively similar

2)  cycling trajectories from different routes are expected to be
    dissimilar, but cycling speed and acceleration patterns between
    individuals are expected to be more dissimilar.

## Risk analysis

<!-- What could be the biggest challenges/problems you might face? What is your plan B? -->

-   Outliers and Missing DATA bc of missing GPS signal in tunnels f.ex.
-   variability of the data due to different transport modes during one
    trajectory (but thats the whole point)
-   recording frequency variablity (14, 17 trips is not a high sampling
    rate)
-   similarity/clustering may take a long computing time
-   Risks of computing method:
    -   using speed thresholds for segmentation of trajectories by
        movement type, leads to misclassification if a fast movement
        type like train happens to travel slower –\> trajectory of one
        movement type is split into several segments.
    -   calculating speed (distance/time) parameters over a larger scale
        leads to parameter underestimation in sinuous trajectories

## Questions?

<!-- Which questions would you like to discuss at the coaching session? -->

If we want to make a "red light ignoring"-Analysis, ow to define
crossroads (=turning points)? Same as "static" definition ? Or somehow
via GIS/additional data?

Did we use moving average/smoothing algorithms already? Chat GTP
suggests we should do that for the segmentation
