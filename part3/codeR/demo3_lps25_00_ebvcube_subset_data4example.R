# install_packages.R

rm(list=ls())
gc()

# Test if the libraries are loaded correctly
library(ebvcube)
library(readr)
library(terra)
library(ggplot2)
library(tidyverse)

library(ebvcube)

#set the path to the file
# file <- system.file(file.path("extdata","martins_comcom_subset.nc"), package="ebvcube")
file <- "C:/gitrepo/B-Cubed_data_mobilization/output/datacubes/nc/ias/IAS_5_metrics_10sps.nc"

#read the properties of the file
prop.file <- ebv_properties(file, verbose=FALSE)

#take a look at the general properties of the data set - there are more properties to discover!
prop.file@general[1:4]
#> $title
#> [1] "Local bird diversity (cSAR/BES-SIM)"
#> 
#> $description
#> [1] "Changes in bird diversity at 1-degree resolution caused by land use, estimated by the cSAR model for 1900-2015 using LUH2.0 historical reconstruction of land-use."
#> 
#> $ebv_class
#> [1] "Community composition"
#> 
#> $ebv_name
#> [1] "Taxonomic and phylogenetic diversity"
slotNames(prop.file)
#> [1] "general"  "spatial"  "temporal" "metric"   "scenario" "ebv_cube"


datacubes <- ebv_datacubepaths(file, verbose=FALSE)
datacubes
#>       datacubepaths                                 metric_names
#> 1 metric_1/ebv_cube Relative change in the number of species (%)
#> 2 metric_2/ebv_cube     Absolute change in the number of species


prop.dc <- ebv_properties(file, datacubes[1,1], verbose=FALSE)
prop.dc@metric
#> $name
#> [1] "Relative change in the number of species (%)"
#> 
#> $description
#> [1] "Relative change in the number of species (S) using the year 1900 as reference (e.g. -50 corresponds to a decrease in 50% of the number of species in the cell since 1900, (S_year-S_1900)/S_1900*100)"

#plot the global map
dc <- datacubes[1,1]
# ebv_map(file, dc, entity=1, timestep = 1, classes = 9,
        # verbose=FALSE, col_rev = TRUE)

data <- ebv_read(file, dc, entity = 1, timestep = 1, type = 'a')
dim(data)
data


#load subset from shapefile (Cameroon)
shp <- system.file(file.path('extdata','cameroon.shp'), package="ebvcube")
data.shp <- ebv_read_shp(file, dc, entity=1, shp = shp, timestep = c(1,2,3), verbose=FALSE)
dim(data.shp)
#> [1] 12  9  3

#very quick plot of the resulting raster plus the shapefile
borders <- terra::vect(shp)
ggplot2::ggplot() +
  # tidyterra::geom_spatraster(data = data[[1]]) +
  tidyterra::geom_spatvector(data = borders, fill = NA) +
  ggplot2::scale_fill_fermenter(na.value=NA, palette = 'YlGn', direction = 1) +
  ggplot2::theme_classic()


# newNc <- file.path(system.file(package="ebvcube"),'extdata','test.nc')


# root <- system.file(file.path('extdata'), package="ebvcube")
tifs <- c('entity1.tif', 'entity2.tif', 'entity3.tif')
tif_paths <- file.path(root, tifs)

rin <- rast(tif_paths[3])
plot(rin)
savePlot()

# Define the extent for Africa (xmin, xmax, ymin, ymax)
africa_extent <- ext(-19, 55, -36, 40)

# Crop the raster to the Africa extent
rout <- crop(rin, africa_extent)

# Plot the cropped raster
plot(rout)
i <- 1

for (i in 1:3){
    rin <- rast(tif_paths[i])
    rout <- crop(rin, africa_extent)
    plot(rout)
    # Save the cropped raster if you want
    writeRaster(rout, paste0("data/tif/entity_", i,"_v2.tif"), overwrite=TRUE)
    }



# Load the NetCDF file
nc_file <- rast(file)

# Print some information about the loaded file
print(nc_file)


# Save as GeoTIFF
dout <- nc_file[[1:5]]
writeRaster(dout, "data/input/exercise/metric1_sp1to5_id82subset.tif", overwrite = TRUE)
dout <- nc_file[[78:83]]
writeRaster(dout, "data/input/exercise/metric2__sp1to5_id82subset.tif", overwrite = TRUE)
dout <- nc_file[[145:149]]
writeRaster(dout, "data/input/exercise/metric3_sp1to5_id82subset.tif", overwrite = TRUE)

