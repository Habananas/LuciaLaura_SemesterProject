#Including all your code index.qmd and rendering it each time you want to preview your report makes your report less error prone and more reproducible, 
#but this workflow can be cumbersome when the code takes a long time to execute. 
#This prevents you iterating fast when writing up your report. We suggest the following method to solve this:
#Outsource your preprocessing steps and especially the heavy computation into a seperate R-Script called preprocessing.R. 
#In this script, generate all outputs that you will need in your report (index.qmd).
#To “prove” that this script runs on your machine from top to bottom, in a new session and without any errors, use the function 
knitr::spin("preprocessing.R") 
#from the package knitr (you might need to install this first). 
#Push the resulting files (preprocessing.html / preprocessing.md) to GitHub (this is a hard requirement).###