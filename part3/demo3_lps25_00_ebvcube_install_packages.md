# LPS25 Demo - Biodiversity Data Cubes for Earth Science (22 June, 2025)
# Part 3: Hands-on training  on the `ebvcube` R package
# Install the packages for the hands-on training on the `ebvcube` R package
# Author: Luise Quoß, Lina Estupinan-Suarez
# Institution: German Centre for Integrative Biodiversity Research

``` r
# Install Bioconductor packages (required for ebvcube)
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
BiocManager::install(c("rhdf5", "HDF5Array", "DelayedArray"))
```

``` r
# Install latest development version of ebvcube from GitHub (recommended)
install.packages("devtools")
devtools::install_github("https://github.com/LuiseQuoss/ebvcube/tree/dev")
```

``` r
# Install additional CRAN packages
install.packages(c("readr", "terra", "ggplot2", "tidyverse", "stringr"))
```

``` r
# Installation complete message
message("All required packages have been installed successfully.")
```

``` r
# Test if the libraries are loaded correctly
library(ebvcube)
library(readr)
library(terra)
library(ggplot2)
library(tidyverse)
library(stringr)
```

# If anything did not work, send an email to lina.estupinans@idiv.de
