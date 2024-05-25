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
|:-----------------|:-----------------------------------------------------|
| **Data:**      | Laura & Lucia Strava Data                                                                      |
| **Title:**     | Movement type detection - the potential of cluster and similarity analysis in low quality data |
| **Student 1:** | Laura Vetter                                                                                   |
| **Student 2:** | Lucia Scheele                                                                                  |

List template: <https://www.w3schools.com/html/html_headings.asp>

## Abstract

As we tried to think of possible project ideas for our semester project,
the quality of our data and the accuracy of the given meta data
confronted us with major limitations. As this seems to be a common
problem for trajectory research (Sadeghian et al. 2020), we will try to
solve this hurdle on a computational basis. Methods applied include
segmentation, k-means clustering and similarity analysis.  

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
resolution. However, data frequency is not consistent and in all cases
due to lack of signal (e.g. in a train).  

Additional data that might be used for the analysis include metadata
from Strava, our individual knowledge about trips and lastly, traffic
infrastructure data by the city of Zurich (
[https://www.stadt-zuerich.ch/geodaten/](#0){.uri} ). While the metadata
from Strava does supply movement type information, it is to be noted
that this data is not accurate in all cases. For example, a track was
recorded as a travel by train but includes the walk or bike to the train
station. In these cases, the personal knowledge of the trips provides an
important addition.  

## Analytical concepts

<u>Conceptual movement spaces and modelling approaches</u>

In Strava, a point with location and timestamp is created by default
every second (if the signal allows for it), it is therefore a discrete
dataset with a relatively high resolution. The scale at which the
spatial data is analyzed is important, as derived movement parameters
(e.g. speed, step length or turning angle) are strongly influenced by it
(Laube, How fast is a cow 2011). This must be considered when conducting
analysis for the different movement types.

<u>Segmentation</u> 

Since some trajectories include several movement types, we will apply
two types of trajectory segmentation:  

In the first step, segmentations will be conducted by considering the
static points (i.e. using the stepMean function developed in class). For
cases where different movement types cannot be seperated by static
points (i.e. changing from walking to running), segmentations will be
achieved with the different characteristics of the respective movement
in a second step. The parameters for the walking segments could be: 

-   Treshhold: longer than 60 seconds 

-   average speed not faster than 6 km/h 

-   maximum speed should not be greater than 12 km/h (otherwise
    running) 

In result, some data is directly classified into one class, whereas some
can be "multiclassfied", meaning it could belong to e.g. running or
walking. Some segments might also be wrongly classified (e.g. train
stops).  Again, if time and resources allow for it, these multi-class
segments are compared with transport infrastructure data. If the
negative acceleration (stopping) of a segment happens in the defined
range of a train station, it could thereby still be classified as a
movement by train. Meanwhile, we must be careful to not to classify
running segments as an incoming train.

<u> Cluster analysis </u>

Concerning the cluster analysis, space and time of trajectories will be
treated to be relative. For the similarity analysis of a repeated
running track, the spatial data is similar and will thus be treated as
absolute.  

The parameters to cluster and to assess similarity of the trajectories
will be the following: 

-   Average, maximum and minimum speed 

-   average acceleration and acceleration during each segment 

-   segment distance 

-   Possibly: direction, duration, azimuth and sinuosity 

If time and resources allow it, an unsupervised learning algorithm
(k-means, as it is the most common in non-hierarchical clustering
methods (Bachir et al., 2018)) will be applied to cluster segments
within and between trajectories. The quality of this analysis will then
be assessed by comparing the results with the STRAVA metadata and our
personal track knowledge.  \
By reducing the number of k, Sadeghian et. Al. (2020) could improve the
performance of the k-means method. Therefore, this analysis will explore
different k-values (i.e. 7,5,4) and, if necessary, reduce the number of
distinct movement types. 

<u> Similarity </u> 

Concerning a homogenuous subset of data where the same route was used
several times, four tracked trajectories will be compared using
different similarity measures (DTW, EditDist, Frechet, LCSS). The
objective is to evaluate how well each similarity measure predicts the
speed and spatial differences of the trajectories. 

## R concepts

<!-- Which R concepts, functions, packages will you mainly use. What additional spatial analysis methods will you be using? -->

| Step in the analysis    | Package used             |
|:------------------------|:-------------------------|
| **Preprocessing**       | readr, dplyr, lubridate, |
| **Segmentation**        | dplyr, lubridate         |
| **Clustering**          | MKMeans {MKMeans}?       |
| **Similarity analysis** | similaritymeasures       |
| **Visulization**        | ggplot, tmap, plotly     |

## Expected Results / products

<u>Movement types</u>

Respective of the different activities that we tracked with Strava, we
expect to find 7 movement types (i.e. walking, running, cycling, bus,
tram, train and car).

<u>Bike Trajectories</u>

When applying the clustering method to our bike trajectories the results
could be affected by several factors. We are curious to see if there
were enough differences in our biking behavior to result in clusters
that each match one person. We are though aware, that for example, a
parameter like biking speed will be correlated to the respective
environment (urban vs. rural, settlement vs. lake-side). If we use this
parameter for the clustering, the results may thus also represent
differences of the respective environment.

<u>Running Trajectories</u>

Concerning the running trajectories, we have three expectations:

1.  Running trajectories from the same route but at different times are
    expected to be relatively similar, and less similar when there are
    spatial dissimilarities.

2.  Cycling trajectories from different routes by one person are
    expected to be dissimilar (because of spatial variation).

3.  Cycling speed and acceleration patterns between individuals are
    expected to be dissimilar because of spatial variation and different
    acceleration and speed behaviour.

## Risk analysis

<!-- What could be the biggest challenges/problems you might face? What is your plan B? -->

According to Lin (2013), the use of an unlabeled dataset to obtain mode
detection with high accuracy in a transport complex urban environment is
challenging. We are curious to see, if this still applies ten years
later. Currently, we are aware of the following challenges:  

-   outliers, e.g. resulting from missing data because of GPS signal
    interruptions in tunnels  

-   variability of the data due to different transport modes during one
    trajectory makes segmentation cumbersome 

-   recording frequency: 14 + 17 trips, is not a high sampling rate.  

-   similarity/clustering may take a long time to compute  

Also, there are differen risks of computing methods: 

-   Using speed thresholds for segmentation of trajectories by movement
    type, leads to misclassification if a fast movement type like train
    happens to travel slower. Thus, a trajectory of one movement type is
    split into several segments.  

-   Calculation of speed (distance/time) parameters over a larger scale
    leads to parameter underestimation in sinuous trajectories 

## Questions?

<!-- Which questions would you like to discuss at the coaching session? -->

Data:  \
How do we deal with inconsistencies of recording frequency (e.g. due to
lack of signal, causing a timelag that differs from the default of 1s?  

Methods: \
- Is there material on using k-means? Is the data used  \
- Does it make sense to use similarity measures for data that is
obviously not similar \
- If we want to analyze the cycling behavior of the two individuals at
crossroads (e.g.: if they slow down or just pass without looking?), how
would we define crossroads (=turning points)? Ideas: by sinuosity (if
more than 45°), by intersection or streets... \
- Did we use moving average/smoothing algorithms already? Yes, we did:
Moving window is a smoothing algorithm... But then are there other
useful smoothing algorithms that we should consider?  \
(Chat GTP suggested smoothing algorithms for the segmentation) 
