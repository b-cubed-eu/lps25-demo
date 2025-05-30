# LPS25 Demo - Biodiversity Data Cubes for Earth Science (22 June, 2025)
# Part 3: Hands-on training  on the `ebvcube` R package
# Script to explore EBVCubes
# Author: Luise Quoß, Lina Estupinan-Suarez
# Institution: German Centre for Integrative Biodiversity Research

# load the ebvcube and stringr package
library(ebvcube)
library(stringr)
library(terra)

# Check if working directory point to this code-folder
getwd()
# If not, run the following line of code
# This only runs if you are using RStudio, else use setwd("your/path/to/lps25-demo/part3/")
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

# Documentation----
# Remember to check the help-pages of the function, e.g. using ?
?ebv_download

# 1. Download ----
# Check all available datasets
downloads <- ebv_download()
head(downloads)

# Download the 'Global trends in biodiversity (BES-SIM PREDICTS)' dataset using the DOI
path <- ebv_download(id = '10.25829/bk5g87', #alternative value: downloads$id[18]
                     outputdir = '../data/') #if error: remove one dot and try again

# 2. Explore available datacubes ----
# Get info about cubes including the hierarchy
cubes <- ebv_datacubepaths(filepath = path)

# This dataset has three scenarios, with four metrics
print(cubes)

# 3. Explore the metadata ----
# Properties for one metric and scenario: the relative species change of scenario 1 (SSP1)
prop <- ebv_properties(filepath = path,
                         metric = 2,
                         scenario = 1)

# How is the relative species change calculated (metric 2)?
prop@metric

# What timesteps (dates) does the dataset cover?
prop@temporal$dates

# What are the dimensions of the datacubes?
prop@spatial$dimensions

# What is the entity of the cube?
prop@general$entity_names

# 4. Read data ----
# Read the data of the species richness for all dates for the SSP3 scenario
# The function returns a terra SpatRast by default. Change the type argument to change.
data <- ebv_read(filepath = path,
                 metric = 'Species richness, S', #alternative value: 1
                 scenario = 'SSP3xRCP6.0 LU', #alternative value: 2
                 timestep = 1:3,
                 entity = 'Alltaxa', #alternative value: 1
                 type = 'r' #change this value to 'a' to get an array
                 )

# Quickly check the data visually using the terra plot function
plot(data[[2]])

# Clean up ----
file.remove(path)
file.remove(paste0(str_remove(path, '.nc'), '_metadata.json'))

