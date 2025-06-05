# B-Cubed DEMO Living Planet Symposium 2025
Maarten Trekels
## Building data cubes



### Install missing packages


```python
%pip install pygbif
%pip install dask
%pip install geopandas
%pip install netCDF4
%pip install rioxarray
%pip install cartopy
%pip install basemap
%pip install xarray-spatial
%pip install contextily
%pip install pystac_client
%pip install planetary_computer
%pip install stackstac
```

### Loading packages


```python
import warnings
warnings.filterwarnings("ignore", message="invalid value encountered in cast")

from pygbif import occurrences as occ
import pandas as pd
import geopandas as gpd
from pyproj import Proj, Transformer
from shapely.geometry import mapping
from shapely.geometry import Polygon
import matplotlib.pyplot as plt


import io
from io import StringIO
import zipfile
import math
from rioxarray.rioxarray import _make_coords
from rasterio.vrt import WarpedVRT

import xrspatial.multispectral as ms

import contextily as ctx
from pystac_client import Client
from pystac.extensions.eo import EOExtension as eo
import rioxarray
import planetary_computer
import affine
import rasterio  # Import rasterio!
import stackstac
```

### Loading Earth Engine

### Example of the GBIF API through pygbif


```python
from pygbif import occurrences
data = occurrences.search(speciesKey=5229490, limit=10)

print(data['results'])
```

## GBIF data Cubes

### Generating the Cube

#### Exemplar JSON query for generating a data cube


```
# DON'T EXECUTE THIS CELL. FOR DEMO PUPOSE ONLY #
{
  "sendNotification": true,
  "notificationAddresses": [
    "maarten.trekels@plantentuinmeise.be"
  ],
  "format": "SQL_TSV_ZIP",
  "sql": "SELECT  PRINTF('%04d-%02d', \"year\", \"month\") AS yearMonth,
   GBIF_EEARGCode(10000, decimalLatitude,  decimalLongitude,  COALESCE(coordinateUncertaintyInMeters, 1000) ) AS eeaCellCode,
   speciesKey,
   species,
   establishmentMeans,
   degreeOfEstablishment,
   pathway,
   COUNT(*) AS occurrences,
   COUNT(DISTINCT recordedBy) AS distinctObservers
   FROM  occurrence
   WHERE occurrenceStatus = 'PRESENT'
   AND countryCode = 'BE'
   AND hasCoordinate = TRUE
   AND NOT ARRAY_CONTAINS(issue, 'ZERO_COORDINATE')
   AND NOT ARRAY_CONTAINS(issue, 'COORDINATE_OUT_OF_RANGE')
   AND NOT ARRAY_CONTAINS(issue, 'COORDINATE_INVALID')
   AND NOT ARRAY_CONTAINS(issue, 'COUNTRY_COORDINATE_MISMATCH')
   AND \"month\" IS NOT NULL
   GROUP BY yearMonth,
   eeaCellCode,
   speciesKey,
   species,
   establishmentMeans,
   degreeOfEstablishment,
   pathway
   ORDER BY  yearMonth DESC,
   eeaCellCode ASC,
   speciesKey ASC"
}


```



## Loading the Data Cube in Python

### Matching the GBIF download with a geometry

ONLY EXECUTE THIS SECTION IF YOU DON'T WANT TO USE THE PRE GENERATED GEOPARQUET FILES

You can download a pre generated data cube from GitHub or any other online resource.

#### Get data from Drive


```python
def convert_to_int(x):
       try:
           return int(x)
       except ValueError:
           return pd.NA  # or np.nan if you prefer NumPy NaNs

data = pd.read_csv('./data/YOUR_GBIF_DOWNLOAS.csv', sep='\t', converters={'familykey': convert_to_int, 'specieskey': convert_to_int})

data['familykey'] = pd.to_numeric(data['familykey'], errors='coerce').astype('Int64')
data['specieskey'] = pd.to_numeric(data['specieskey'], errors='coerce').astype('Int64')

```


```python
print(data)
```

#### Getting a Geopackage file from the Grid that you use


```python
input_file = "./data/YOUR_GRID.gpkg"

qdgc_ref = gpd.read_file(input_file, layer='tbl_qdgc_03')
```


```python
print(qdgc_ref)
```

#### Merging the Data cube with the grid


```python
test_merge = pd.merge(data, qdgc_ref, left_on='qdgccode', right_on='qdgc')
```


```python
# Convert to GeoDataFrame

gdf = gpd.GeoDataFrame(test_merge, geometry='geometry')

gdf = gdf.set_crs(epsg=4326, inplace=False)
```

## Loading the data from a GeoParquet file

### Loading the data as GeoDataFrames


```python
gbif_cube = './data/data_ZA.parquet'
gbif_points = './data/data_ZA_occurrence.parquet'

gdf_cube = gpd.read_parquet(gbif_cube)
gdf_point = gpd.read_parquet(gbif_points)
```


```python
print(gdf_cube)
```

           kingdom  kingdomkey        phylum  phylumkey          class  classkey  \
    0      Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    1      Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    2      Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    3      Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    4      Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    ...        ...         ...           ...        ...            ...       ...   
    11040  Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    11041  Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    11042  Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    11043  Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    11044  Plantae           6  Tracheophyta    7707728  Magnoliopsida       220   
    
             order  orderkey    family  familykey  ... phylumcount  classcount  \
    0      Fabales      1370  Fabaceae       5386  ...           1           1   
    1      Fabales      1370  Fabaceae       5386  ...           1           1   
    2      Fabales      1370  Fabaceae       5386  ...           1           1   
    3      Fabales      1370  Fabaceae       5386  ...           1           1   
    4      Fabales      1370  Fabaceae       5386  ...           1           1   
    ...        ...       ...       ...        ...  ...         ...         ...   
    11040  Fabales      1370  Fabaceae       5386  ...           1           1   
    11041  Fabales      1370  Fabaceae       5386  ...           1           1   
    11042  Fabales      1370  Fabaceae       5386  ...           1           1   
    11043  Fabales      1370  Fabaceae       5386  ...           1           1   
    11044  Fabales      1370  Fabaceae       5386  ...           1           1   
    
          ordercount  familycount genuscount occurrences  mintemporaluncertainty  \
    0              1            1          1           1                      60   
    1              1            1          1           1                      60   
    2              1            1          1           1                   86400   
    3              1            1          1           1                      60   
    4              1            1          1           1                      60   
    ...          ...          ...        ...         ...                     ...   
    11040          1            1          1           1                       1   
    11041          1            1          1           1                      60   
    11042          1            1          1           1                   86400   
    11043          1            1          1           1                   86400   
    11044          1            1          1           1                   86400   
    
           mincoordinateuncertaintyinmeters     cellCode  \
    0                             1575268.0  E009S27CCBD   
    1                                  19.0  E016S28BDCA   
    2                                1000.0  E016S28CBBD   
    3                                  31.0  E016S28DAAC   
    4                                1000.0  E016S28DAAC   
    ...                                 ...          ...   
    11040                               4.0  E031S29CABC   
    11041                              61.0  E031S29CCAA   
    11042                            1000.0  E031S29CCBC   
    11043                            1000.0  E031S29CCBC   
    11044                            1000.0  E031S29CCDA   
    
                                                    geometry  
    0      POLYGON ((9.1875 -27.875, 9.25 -27.875, 9.25 -...  
    1      POLYGON ((16.75 -28.4375, 16.8125 -28.4375, 16...  
    2      POLYGON ((16.4375 -28.625, 16.5 -28.625, 16.5 ...  
    3      POLYGON ((16.5 -28.625, 16.5625 -28.625, 16.56...  
    4      POLYGON ((16.5 -28.625, 16.5625 -28.625, 16.56...  
    ...                                                  ...  
    11040  POLYGON ((31.125 -29.625, 31.1875 -29.625, 31....  
    11041  POLYGON ((31 -29.8125, 31.0625 -29.8125, 31.06...  
    11042  POLYGON ((31.125 -29.875, 31.1875 -29.875, 31....  
    11043  POLYGON ((31.125 -29.875, 31.1875 -29.875, 31....  
    11044  POLYGON ((31.125 -29.9375, 31.1875 -29.9375, 3...  
    
    [11045 rows x 27 columns]


### Filtering data (e.g. on species)
Check for a single species (Acacia melanoxylon R.Br.: https://www.gbif.org/species/2979000)


```python
gdf_cube = gdf_cube[gdf_cube['specieskey'].eq(2979775)]
gdf_point = gdf_point[gdf_point['speciesKey'].eq(2979775.0)]
```

## Visualization of the data cubes on a map with different layers

### Plotting the data on OpenStreetMap


```python


bbox_total = gdf_cube.total_bounds

bbox = [18.113532, -34.393312, 18.852118, -33.543684] #ZA bbox

aoi = {
    "type": "Polygon",
    "coordinates": [[
        [bbox[0], bbox[1]],
        [bbox[2], bbox[1]],
        [bbox[2], bbox[3]],
        [bbox[0], bbox[3]],
        [bbox[0], bbox[1]],
    ]],
}




# 5. Plot the Data
fig, ax = plt.subplots(figsize=(20, 16))


# Plot the GeoDataFrames
gdf_cube.plot(ax=ax, color="red", edgecolor="black", linewidth=1, alpha=0.5)
gdf_point.plot(ax=ax, color="blue", edgecolor="black", linewidth=1, alpha=0.5)

# Adjust Axes
ax.set_xlim(bbox[0], bbox[2])
ax.set_ylim(bbox[1], bbox[3])

ctx.add_basemap(ax, source=ctx.providers.OpenStreetMap.Mapnik, crs="EPSG:4326")


# Labels and Title
plt.title("GeoPandas DataFrame on OpenStreetMap Background")
plt.xlabel("Longitude")
plt.ylabel("Latitude")

# Show the Plot
plt.show()
```


    
![png](output_32_0.png)
    


### Getting Sentinel-2 image from Microsoft Planetary Computer


```python
catalog = Client.open("https://planetarycomputer.microsoft.com/api/stac/v1", modifier=planetary_computer.sign_inplace)


items = catalog.search(
    collections=["sentinel-2-l2a"],
    query={"id": {"eq": "S2B_MSIL2A_20250404T081609_R121_T34HBH_20250404T120818"}}
).items()


least_cloudy_item = next(items)

print(
    f"Choosing {least_cloudy_item.id} from {least_cloudy_item.datetime.date()}"
    f" with {eo.ext(least_cloudy_item).cloud_cover}% cloud cover"
)

scene_data = (
    stackstac.stack(
        [least_cloudy_item.to_dict()],
        epsg=4326,
        resampling=rasterio.enums.Resampling.bilinear,
        #resolution=0.001,  # resolution in the output CRS’s units
        assets=["B04", "B03", "B02"],  # red, green, blue bands
        chunksize=2048,
    )
    .isel(time=0)
    .persist()
)

scene_data
```

    Choosing S2B_MSIL2A_20250404T081609_R121_T34HBH_20250404T120818 from 2025-04-04 with 2.005319% cloud cover





<div><svg style="position: absolute; width: 0; height: 0; overflow: hidden">
<defs>
<symbol id="icon-database" viewBox="0 0 32 32">
<path d="M16 0c-8.837 0-16 2.239-16 5v4c0 2.761 7.163 5 16 5s16-2.239 16-5v-4c0-2.761-7.163-5-16-5z"></path>
<path d="M16 17c-8.837 0-16-2.239-16-5v6c0 2.761 7.163 5 16 5s16-2.239 16-5v-6c0 2.761-7.163 5-16 5z"></path>
<path d="M16 26c-8.837 0-16-2.239-16-5v6c0 2.761 7.163 5 16 5s16-2.239 16-5v-6c0 2.761-7.163 5-16 5z"></path>
</symbol>
<symbol id="icon-file-text2" viewBox="0 0 32 32">
<path d="M28.681 7.159c-0.694-0.947-1.662-2.053-2.724-3.116s-2.169-2.030-3.116-2.724c-1.612-1.182-2.393-1.319-2.841-1.319h-15.5c-1.378 0-2.5 1.121-2.5 2.5v27c0 1.378 1.122 2.5 2.5 2.5h23c1.378 0 2.5-1.122 2.5-2.5v-19.5c0-0.448-0.137-1.23-1.319-2.841zM24.543 5.457c0.959 0.959 1.712 1.825 2.268 2.543h-4.811v-4.811c0.718 0.556 1.584 1.309 2.543 2.268zM28 29.5c0 0.271-0.229 0.5-0.5 0.5h-23c-0.271 0-0.5-0.229-0.5-0.5v-27c0-0.271 0.229-0.5 0.5-0.5 0 0 15.499-0 15.5 0v7c0 0.552 0.448 1 1 1h7v19.5z"></path>
<path d="M23 26h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
<path d="M23 22h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
<path d="M23 18h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
</symbol>
</defs>
</svg>
<style>/* CSS stylesheet for displaying xarray objects in jupyterlab.
 *
 */

:root {
  --xr-font-color0: var(--jp-content-font-color0, rgba(0, 0, 0, 1));
  --xr-font-color2: var(--jp-content-font-color2, rgba(0, 0, 0, 0.54));
  --xr-font-color3: var(--jp-content-font-color3, rgba(0, 0, 0, 0.38));
  --xr-border-color: var(--jp-border-color2, #e0e0e0);
  --xr-disabled-color: var(--jp-layout-color3, #bdbdbd);
  --xr-background-color: var(--jp-layout-color0, white);
  --xr-background-color-row-even: var(--jp-layout-color1, white);
  --xr-background-color-row-odd: var(--jp-layout-color2, #eeeeee);
}

html[theme="dark"],
html[data-theme="dark"],
body[data-theme="dark"],
body.vscode-dark {
  --xr-font-color0: rgba(255, 255, 255, 1);
  --xr-font-color2: rgba(255, 255, 255, 0.54);
  --xr-font-color3: rgba(255, 255, 255, 0.38);
  --xr-border-color: #1f1f1f;
  --xr-disabled-color: #515151;
  --xr-background-color: #111111;
  --xr-background-color-row-even: #111111;
  --xr-background-color-row-odd: #313131;
}

.xr-wrap {
  display: block !important;
  min-width: 300px;
  max-width: 700px;
}

.xr-text-repr-fallback {
  /* fallback to plain text repr when CSS is not injected (untrusted notebook) */
  display: none;
}

.xr-header {
  padding-top: 6px;
  padding-bottom: 6px;
  margin-bottom: 4px;
  border-bottom: solid 1px var(--xr-border-color);
}

.xr-header > div,
.xr-header > ul {
  display: inline;
  margin-top: 0;
  margin-bottom: 0;
}

.xr-obj-type,
.xr-array-name {
  margin-left: 2px;
  margin-right: 10px;
}

.xr-obj-type {
  color: var(--xr-font-color2);
}

.xr-sections {
  padding-left: 0 !important;
  display: grid;
  grid-template-columns: 150px auto auto 1fr 0 20px 0 20px;
}

.xr-section-item {
  display: contents;
}

.xr-section-item input {
  display: inline-block;
  opacity: 0;
  height: 0;
}

.xr-section-item input + label {
  color: var(--xr-disabled-color);
}

.xr-section-item input:enabled + label {
  cursor: pointer;
  color: var(--xr-font-color2);
}

.xr-section-item input:focus + label {
  border: 2px solid var(--xr-font-color0);
}

.xr-section-item input:enabled + label:hover {
  color: var(--xr-font-color0);
}

.xr-section-summary {
  grid-column: 1;
  color: var(--xr-font-color2);
  font-weight: 500;
}

.xr-section-summary > span {
  display: inline-block;
  padding-left: 0.5em;
}

.xr-section-summary-in:disabled + label {
  color: var(--xr-font-color2);
}

.xr-section-summary-in + label:before {
  display: inline-block;
  content: "►";
  font-size: 11px;
  width: 15px;
  text-align: center;
}

.xr-section-summary-in:disabled + label:before {
  color: var(--xr-disabled-color);
}

.xr-section-summary-in:checked + label:before {
  content: "▼";
}

.xr-section-summary-in:checked + label > span {
  display: none;
}

.xr-section-summary,
.xr-section-inline-details {
  padding-top: 4px;
  padding-bottom: 4px;
}

.xr-section-inline-details {
  grid-column: 2 / -1;
}

.xr-section-details {
  display: none;
  grid-column: 1 / -1;
  margin-bottom: 5px;
}

.xr-section-summary-in:checked ~ .xr-section-details {
  display: contents;
}

.xr-array-wrap {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: 20px auto;
}

.xr-array-wrap > label {
  grid-column: 1;
  vertical-align: top;
}

.xr-preview {
  color: var(--xr-font-color3);
}

.xr-array-preview,
.xr-array-data {
  padding: 0 5px !important;
  grid-column: 2;
}

.xr-array-data,
.xr-array-in:checked ~ .xr-array-preview {
  display: none;
}

.xr-array-in:checked ~ .xr-array-data,
.xr-array-preview {
  display: inline-block;
}

.xr-dim-list {
  display: inline-block !important;
  list-style: none;
  padding: 0 !important;
  margin: 0;
}

.xr-dim-list li {
  display: inline-block;
  padding: 0;
  margin: 0;
}

.xr-dim-list:before {
  content: "(";
}

.xr-dim-list:after {
  content: ")";
}

.xr-dim-list li:not(:last-child):after {
  content: ",";
  padding-right: 5px;
}

.xr-has-index {
  font-weight: bold;
}

.xr-var-list,
.xr-var-item {
  display: contents;
}

.xr-var-item > div,
.xr-var-item label,
.xr-var-item > .xr-var-name span {
  background-color: var(--xr-background-color-row-even);
  margin-bottom: 0;
}

.xr-var-item > .xr-var-name:hover span {
  padding-right: 5px;
}

.xr-var-list > li:nth-child(odd) > div,
.xr-var-list > li:nth-child(odd) > label,
.xr-var-list > li:nth-child(odd) > .xr-var-name span {
  background-color: var(--xr-background-color-row-odd);
}

.xr-var-name {
  grid-column: 1;
}

.xr-var-dims {
  grid-column: 2;
}

.xr-var-dtype {
  grid-column: 3;
  text-align: right;
  color: var(--xr-font-color2);
}

.xr-var-preview {
  grid-column: 4;
}

.xr-index-preview {
  grid-column: 2 / 5;
  color: var(--xr-font-color2);
}

.xr-var-name,
.xr-var-dims,
.xr-var-dtype,
.xr-preview,
.xr-attrs dt {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding-right: 10px;
}

.xr-var-name:hover,
.xr-var-dims:hover,
.xr-var-dtype:hover,
.xr-attrs dt:hover {
  overflow: visible;
  width: auto;
  z-index: 1;
}

.xr-var-attrs,
.xr-var-data,
.xr-index-data {
  display: none;
  background-color: var(--xr-background-color) !important;
  padding-bottom: 5px !important;
}

.xr-var-attrs-in:checked ~ .xr-var-attrs,
.xr-var-data-in:checked ~ .xr-var-data,
.xr-index-data-in:checked ~ .xr-index-data {
  display: block;
}

.xr-var-data > table {
  float: right;
}

.xr-var-name span,
.xr-var-data,
.xr-index-name div,
.xr-index-data,
.xr-attrs {
  padding-left: 25px !important;
}

.xr-attrs,
.xr-var-attrs,
.xr-var-data,
.xr-index-data {
  grid-column: 1 / -1;
}

dl.xr-attrs {
  padding: 0;
  margin: 0;
  display: grid;
  grid-template-columns: 125px auto;
}

.xr-attrs dt,
.xr-attrs dd {
  padding: 0;
  margin: 0;
  float: left;
  padding-right: 10px;
  width: auto;
}

.xr-attrs dt {
  font-weight: normal;
  grid-column: 1;
}

.xr-attrs dt:hover span {
  display: inline-block;
  background: var(--xr-background-color);
  padding-right: 10px;
}

.xr-attrs dd {
  grid-column: 2;
  white-space: pre-wrap;
  word-break: break-all;
}

.xr-icon-database,
.xr-icon-file-text2,
.xr-no-icon {
  display: inline-block;
  vertical-align: middle;
  width: 1em;
  height: 1.5em !important;
  stroke-width: 0;
  stroke: currentColor;
  fill: currentColor;
}
</style><pre class='xr-text-repr-fallback'>&lt;xarray.DataArray &#x27;stackstac-2a49b23b9ff19b22b940b9e0eff1c21a&#x27; (band: 3,
                                                                y: 10981,
                                                                x: 10981)&gt; Size: 3GB
dask.array&lt;getitem, shape=(3, 10981, 10981), dtype=float64, chunksize=(1, 2048, 2048), chunktype=numpy.ndarray&gt;
Coordinates: (12/45)
    time                                     datetime64[ns] 8B 2025-04-04T08:...
    id                                       &lt;U54 216B &#x27;S2B_MSIL2A_20250404T0...
  * band                                     (band) &lt;U3 36B &#x27;B04&#x27; &#x27;B03&#x27; &#x27;B02&#x27;
  * x                                        (x) float64 88kB 17.74 ... 18.95
  * y                                        (y) float64 88kB -33.4 ... -34.41
    s2:high_proba_clouds_percentage          float64 8B 0.5189
    ...                                       ...
    proj:shape                               object 8B {10980}
    gsd                                      float64 8B 10.0
    common_name                              (band) &lt;U5 60B &#x27;red&#x27; &#x27;green&#x27; &#x27;blue&#x27;
    center_wavelength                        (band) float64 24B 0.665 0.56 0.49
    full_width_half_max                      (band) float64 24B 0.038 ... 0.098
    epsg                                     int64 8B 4326
Attributes:
    spec:           RasterSpec(epsg=4326, bounds=(17.736915050109257, -34.411...
    crs:            epsg:4326
    transform:      | 0.00, 0.00, 17.74|\n| 0.00,-0.00,-33.40|\n| 0.00, 0.00,...
    resolution_xy:  (0.00011084602003642967, 9.237950819672146e-05)</pre><div class='xr-wrap' style='display:none'><div class='xr-header'><div class='xr-obj-type'>xarray.DataArray</div><div class='xr-array-name'>'stackstac-2a49b23b9ff19b22b940b9e0eff1c21a'</div><ul class='xr-dim-list'><li><span class='xr-has-index'>band</span>: 3</li><li><span class='xr-has-index'>y</span>: 10981</li><li><span class='xr-has-index'>x</span>: 10981</li></ul></div><ul class='xr-sections'><li class='xr-section-item'><div class='xr-array-wrap'><input id='section-4ea49ce1-5f4f-4f76-a625-a926aa166034' class='xr-array-in' type='checkbox' checked><label for='section-4ea49ce1-5f4f-4f76-a625-a926aa166034' title='Show/hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-array-preview xr-preview'><span>dask.array&lt;chunksize=(1, 2048, 2048), meta=np.ndarray&gt;</span></div><div class='xr-array-data'><table>
    <tr>
        <td>
            <table style="border-collapse: collapse;">
                <thead>
                    <tr>
                        <td> </td>
                        <th> Array </th>
                        <th> Chunk </th>
                    </tr>
                </thead>
                <tbody>

                    <tr>
                        <th> Bytes </th>
                        <td> 2.70 GiB </td>
                        <td> 32.00 MiB </td>
                    </tr>

                    <tr>
                        <th> Shape </th>
                        <td> (3, 10981, 10981) </td>
                        <td> (1, 2048, 2048) </td>
                    </tr>
                    <tr>
                        <th> Dask graph </th>
                        <td colspan="2"> 108 chunks in 1 graph layer </td>
                    </tr>
                    <tr>
                        <th> Data type </th>
                        <td colspan="2"> float64 numpy.ndarray </td>
                    </tr>
                </tbody>
            </table>
        </td>
        <td>
        <svg width="194" height="184" style="stroke:rgb(0,0,0);stroke-width:1" >

  <!-- Horizontal lines -->
  <line x1="10" y1="0" x2="24" y2="14" style="stroke-width:2" />
  <line x1="10" y1="22" x2="24" y2="37" />
  <line x1="10" y1="44" x2="24" y2="59" />
  <line x1="10" y1="67" x2="24" y2="82" />
  <line x1="10" y1="89" x2="24" y2="104" />
  <line x1="10" y1="111" x2="24" y2="126" />
  <line x1="10" y1="120" x2="24" y2="134" style="stroke-width:2" />

  <!-- Vertical lines -->
  <line x1="10" y1="0" x2="10" y2="120" style="stroke-width:2" />
  <line x1="14" y1="4" x2="14" y2="124" />
  <line x1="19" y1="9" x2="19" y2="129" />
  <line x1="24" y1="14" x2="24" y2="134" style="stroke-width:2" />

  <!-- Colored Rectangle -->
  <polygon points="10.0,0.0 24.9485979497544,14.948597949754403 24.9485979497544,134.9485979497544 10.0,120.0" style="fill:#ECB172A0;stroke-width:0"/>

  <!-- Horizontal lines -->
  <line x1="10" y1="0" x2="130" y2="0" style="stroke-width:2" />
  <line x1="14" y1="4" x2="134" y2="4" />
  <line x1="19" y1="9" x2="139" y2="9" />
  <line x1="24" y1="14" x2="144" y2="14" style="stroke-width:2" />

  <!-- Vertical lines -->
  <line x1="10" y1="0" x2="24" y2="14" style="stroke-width:2" />
  <line x1="32" y1="0" x2="47" y2="14" />
  <line x1="54" y1="0" x2="69" y2="14" />
  <line x1="77" y1="0" x2="92" y2="14" />
  <line x1="99" y1="0" x2="114" y2="14" />
  <line x1="121" y1="0" x2="136" y2="14" />
  <line x1="130" y1="0" x2="144" y2="14" style="stroke-width:2" />

  <!-- Colored Rectangle -->
  <polygon points="10.0,0.0 130.0,0.0 144.9485979497544,14.948597949754403 24.9485979497544,14.948597949754403" style="fill:#ECB172A0;stroke-width:0"/>

  <!-- Horizontal lines -->
  <line x1="24" y1="14" x2="144" y2="14" style="stroke-width:2" />
  <line x1="24" y1="37" x2="144" y2="37" />
  <line x1="24" y1="59" x2="144" y2="59" />
  <line x1="24" y1="82" x2="144" y2="82" />
  <line x1="24" y1="104" x2="144" y2="104" />
  <line x1="24" y1="126" x2="144" y2="126" />
  <line x1="24" y1="134" x2="144" y2="134" style="stroke-width:2" />

  <!-- Vertical lines -->
  <line x1="24" y1="14" x2="24" y2="134" style="stroke-width:2" />
  <line x1="47" y1="14" x2="47" y2="134" />
  <line x1="69" y1="14" x2="69" y2="134" />
  <line x1="92" y1="14" x2="92" y2="134" />
  <line x1="114" y1="14" x2="114" y2="134" />
  <line x1="136" y1="14" x2="136" y2="134" />
  <line x1="144" y1="14" x2="144" y2="134" style="stroke-width:2" />

  <!-- Colored Rectangle -->
  <polygon points="24.9485979497544,14.948597949754403 144.9485979497544,14.948597949754403 144.9485979497544,134.9485979497544 24.9485979497544,134.9485979497544" style="fill:#ECB172A0;stroke-width:0"/>

  <!-- Text -->
  <text x="84.948598" y="154.948598" font-size="1.0rem" font-weight="100" text-anchor="middle" >10981</text>
  <text x="164.948598" y="74.948598" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(-90,164.948598,74.948598)">10981</text>
  <text x="7.474299" y="147.474299" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(45,7.474299,147.474299)">3</text>
</svg>
        </td>
    </tr>
</table></div></div></li><li class='xr-section-item'><input id='section-ba9faf48-cf45-4db7-b117-8d05d85a345b' class='xr-section-summary-in' type='checkbox'  ><label for='section-ba9faf48-cf45-4db7-b117-8d05d85a345b' class='xr-section-summary' >Coordinates: <span>(45)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><ul class='xr-var-list'><li class='xr-var-item'><div class='xr-var-name'><span>time</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>datetime64[ns]</div><div class='xr-var-preview xr-preview'>2025-04-04T08:16:09.024000</div><input id='attrs-565b6370-442d-4e82-ad48-cca46c147efc' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-565b6370-442d-4e82-ad48-cca46c147efc' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-93ad3f4d-d26d-4734-a309-8172a4013f0e' class='xr-var-data-in' type='checkbox'><label for='data-93ad3f4d-d26d-4734-a309-8172a4013f0e' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;2025-04-04T08:16:09.024000000&#x27;, dtype=&#x27;datetime64[ns]&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>id</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U54</div><div class='xr-var-preview xr-preview'>&#x27;S2B_MSIL2A_20250404T081609_R121...</div><input id='attrs-63d4752f-585f-4e95-a1b1-f1a20c02e245' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-63d4752f-585f-4e95-a1b1-f1a20c02e245' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-6512f855-3b18-4fd8-ad8d-b641a502ada1' class='xr-var-data-in' type='checkbox'><label for='data-6512f855-3b18-4fd8-ad8d-b641a502ada1' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;S2B_MSIL2A_20250404T081609_R121_T34HBH_20250404T120818&#x27;,
      dtype=&#x27;&lt;U54&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>band</span></div><div class='xr-var-dims'>(band)</div><div class='xr-var-dtype'>&lt;U3</div><div class='xr-var-preview xr-preview'>&#x27;B04&#x27; &#x27;B03&#x27; &#x27;B02&#x27;</div><input id='attrs-502be7e1-cde3-4601-b954-8a314e297202' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-502be7e1-cde3-4601-b954-8a314e297202' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-8cec2752-4a21-4005-a64f-577396831dcc' class='xr-var-data-in' type='checkbox'><label for='data-8cec2752-4a21-4005-a64f-577396831dcc' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array([&#x27;B04&#x27;, &#x27;B03&#x27;, &#x27;B02&#x27;], dtype=&#x27;&lt;U3&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>x</span></div><div class='xr-var-dims'>(x)</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>17.74 17.74 17.74 ... 18.95 18.95</div><input id='attrs-128d7aa8-65c5-4d73-94af-f70d98dcc667' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-128d7aa8-65c5-4d73-94af-f70d98dcc667' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-ce0d8406-4eef-45ad-8655-498f74381328' class='xr-var-data-in' type='checkbox'><label for='data-ce0d8406-4eef-45ad-8655-498f74381328' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array([17.736915, 17.737026, 17.737137, ..., 18.953783, 18.953894, 18.954004])</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>y</span></div><div class='xr-var-dims'>(y)</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>-33.4 -33.4 -33.4 ... -34.41 -34.41</div><input id='attrs-0d7ebfeb-e9f3-49e7-887f-72fd6c9ef06f' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-0d7ebfeb-e9f3-49e7-887f-72fd6c9ef06f' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-12efacd8-e773-42c6-be17-3667975f9d1a' class='xr-var-data-in' type='checkbox'><label for='data-12efacd8-e773-42c6-be17-3667975f9d1a' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array([-33.397409, -33.397502, -33.397594, ..., -34.411552, -34.411644,
       -34.411736])</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:high_proba_clouds_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.5189</div><input id='attrs-85391487-038f-408c-8bb6-fbfa50b3b3de' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-85391487-038f-408c-8bb6-fbfa50b3b3de' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-d1b79261-977d-4797-ad51-0a957b778c36' class='xr-var-data-in' type='checkbox'><label for='data-d1b79261-977d-4797-ad51-0a957b778c36' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.518945)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:mean_solar_zenith</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>48.79</div><input id='attrs-dce070bc-c111-474c-b043-68629c2dbd26' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-dce070bc-c111-474c-b043-68629c2dbd26' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-22e8023a-97f5-48b5-9cec-a608b5b1dd3c' class='xr-var-data-in' type='checkbox'><label for='data-22e8023a-97f5-48b5-9cec-a608b5b1dd3c' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(48.79287484)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>eo:cloud_cover</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>2.005</div><input id='attrs-f74789e6-cf92-477c-a6f8-f0494c865639' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-f74789e6-cf92-477c-a6f8-f0494c865639' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-06b6d872-7e37-4bc8-9ffe-539bee2d1cb7' class='xr-var-data-in' type='checkbox'><label for='data-06b6d872-7e37-4bc8-9ffe-539bee2d1cb7' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(2.005319)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:snow_ice_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.01235</div><input id='attrs-c691f77a-8bee-4692-a234-36e1d55c29c6' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-c691f77a-8bee-4692-a234-36e1d55c29c6' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-531b3140-fac0-4580-aebd-8b7a57c3ff90' class='xr-var-data-in' type='checkbox'><label for='data-531b3140-fac0-4580-aebd-8b7a57c3ff90' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.01235)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:mean_solar_azimuth</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>41.25</div><input id='attrs-3b0915f7-1e11-4517-ab2c-5c4be7165c44' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-3b0915f7-1e11-4517-ab2c-5c4be7165c44' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-91eff7f1-630e-4809-b007-8dcb658d5bfe' class='xr-var-data-in' type='checkbox'><label for='data-91eff7f1-630e-4809-b007-8dcb658d5bfe' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(41.25282022)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:unclassified_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.04281</div><input id='attrs-f9d239ab-7a93-47a9-b89e-ed692132a486' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-f9d239ab-7a93-47a9-b89e-ed692132a486' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-3f4081a6-2813-43ee-a029-bd52ee9c4c38' class='xr-var-data-in' type='checkbox'><label for='data-3f4081a6-2813-43ee-a029-bd52ee9c4c38' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.042808)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:mgrs_tile</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U5</div><div class='xr-var-preview xr-preview'>&#x27;34HBH&#x27;</div><input id='attrs-961fb83b-6e82-425a-b90f-fea22fc7a1ca' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-961fb83b-6e82-425a-b90f-fea22fc7a1ca' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-f412fc56-ef38-44ae-8b5c-9e1ae343ea28' class='xr-var-data-in' type='checkbox'><label for='data-f412fc56-ef38-44ae-8b5c-9e1ae343ea28' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;34HBH&#x27;, dtype=&#x27;&lt;U5&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:reflectance_conversion_factor</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>1.002</div><input id='attrs-dcb39e60-7549-4e66-9adb-e7b0aeba82d9' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-dcb39e60-7549-4e66-9adb-e7b0aeba82d9' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-d4a07df1-8e98-43a5-9cd4-2b72f796605d' class='xr-var-data-in' type='checkbox'><label for='data-d4a07df1-8e98-43a5-9cd4-2b72f796605d' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(1.00235673)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:product_uri</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U65</div><div class='xr-var-preview xr-preview'>&#x27;S2B_MSIL2A_20250404T081609_N051...</div><input id='attrs-0f8d3df3-489d-4f21-9d99-63ff6a986df3' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-0f8d3df3-489d-4f21-9d99-63ff6a986df3' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-97a39aa4-73a9-4697-a3c0-3a260edda049' class='xr-var-data-in' type='checkbox'><label for='data-97a39aa4-73a9-4697-a3c0-3a260edda049' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;S2B_MSIL2A_20250404T081609_N0511_R121_T34HBH_20250404T120818.SAFE&#x27;,
      dtype=&#x27;&lt;U65&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>platform</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U11</div><div class='xr-var-preview xr-preview'>&#x27;Sentinel-2B&#x27;</div><input id='attrs-bf1c7a3f-5e6e-4be3-bd66-cbd7d4054427' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-bf1c7a3f-5e6e-4be3-bd66-cbd7d4054427' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-3d623218-0226-45a3-a0c3-e397757d943a' class='xr-var-data-in' type='checkbox'><label for='data-3d623218-0226-45a3-a0c3-e397757d943a' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;Sentinel-2B&#x27;, dtype=&#x27;&lt;U11&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:thin_cirrus_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.846</div><input id='attrs-91340506-1da5-4b75-8102-6d946274eb58' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-91340506-1da5-4b75-8102-6d946274eb58' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-d9deb105-273e-4c7d-8095-d36ff8c1c25e' class='xr-var-data-in' type='checkbox'><label for='data-d9deb105-273e-4c7d-8095-d36ff8c1c25e' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.846016)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>instruments</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U3</div><div class='xr-var-preview xr-preview'>&#x27;msi&#x27;</div><input id='attrs-b991519b-d503-4798-9eba-aa188f3af266' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-b991519b-d503-4798-9eba-aa188f3af266' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-63d76d69-673f-4448-b891-3b05bec46895' class='xr-var-data-in' type='checkbox'><label for='data-63d76d69-673f-4448-b891-3b05bec46895' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;msi&#x27;, dtype=&#x27;&lt;U3&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:generation_time</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U27</div><div class='xr-var-preview xr-preview'>&#x27;2025-04-04T12:08:18.000000Z&#x27;</div><input id='attrs-3ccb857a-252d-4716-8ec1-95e71b34f4fb' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-3ccb857a-252d-4716-8ec1-95e71b34f4fb' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-74fa3b83-5e6c-409f-ba83-8b6ba8cb0cfc' class='xr-var-data-in' type='checkbox'><label for='data-74fa3b83-5e6c-409f-ba83-8b6ba8cb0cfc' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;2025-04-04T12:08:18.000000Z&#x27;, dtype=&#x27;&lt;U27&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:datatake_type</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U8</div><div class='xr-var-preview xr-preview'>&#x27;INS-NOBS&#x27;</div><input id='attrs-7f74a03c-995e-4760-b5ce-544490ef9d49' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-7f74a03c-995e-4760-b5ce-544490ef9d49' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-d1904eb8-fb51-4730-96cb-578fc34e1186' class='xr-var-data-in' type='checkbox'><label for='data-d1904eb8-fb51-4730-96cb-578fc34e1186' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;INS-NOBS&#x27;, dtype=&#x27;&lt;U8&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:datatake_id</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U34</div><div class='xr-var-preview xr-preview'>&#x27;GS2B_20250404T081609_042189_N05...</div><input id='attrs-bfb324f5-ca10-4e0a-b72b-93c24a567166' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-bfb324f5-ca10-4e0a-b72b-93c24a567166' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-19803572-9d10-4973-a3dc-6061aa2d1887' class='xr-var-data-in' type='checkbox'><label for='data-19803572-9d10-4973-a3dc-6061aa2d1887' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;GS2B_20250404T081609_042189_N05.11&#x27;, dtype=&#x27;&lt;U34&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>constellation</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U10</div><div class='xr-var-preview xr-preview'>&#x27;Sentinel 2&#x27;</div><input id='attrs-d09bf731-6a5b-4eff-8177-6d0a1614ffc5' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-d09bf731-6a5b-4eff-8177-6d0a1614ffc5' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-68071495-f618-4d6d-946e-9069da0b097b' class='xr-var-data-in' type='checkbox'><label for='data-68071495-f618-4d6d-946e-9069da0b097b' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;Sentinel 2&#x27;, dtype=&#x27;&lt;U10&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:cloud_shadow_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.4579</div><input id='attrs-01369572-eaa1-4aef-9957-117990516258' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-01369572-eaa1-4aef-9957-117990516258' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-7c4ed905-b9d3-46fa-8d9d-204acf11f7ae' class='xr-var-data-in' type='checkbox'><label for='data-7c4ed905-b9d3-46fa-8d9d-204acf11f7ae' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.457893)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>sat:relative_orbit</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>int64</div><div class='xr-var-preview xr-preview'>121</div><input id='attrs-f5681e8f-bc42-4300-850f-ea429143e1e7' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-f5681e8f-bc42-4300-850f-ea429143e1e7' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-39492d9b-74c0-402a-8b77-12859782a0aa' class='xr-var-data-in' type='checkbox'><label for='data-39492d9b-74c0-402a-8b77-12859782a0aa' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(121)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:degraded_msi_data_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.0216</div><input id='attrs-5011f949-400c-4555-9231-cbca4cac870d' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-5011f949-400c-4555-9231-cbca4cac870d' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-9b85aee6-8380-4fbb-b33b-a45ec2a5d716' class='xr-var-data-in' type='checkbox'><label for='data-9b85aee6-8380-4fbb-b33b-a45ec2a5d716' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.0216)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:nodata_pixel_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.08789</div><input id='attrs-6041f723-210e-4a8a-af10-9d128c16128a' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-6041f723-210e-4a8a-af10-9d128c16128a' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-e4db40f5-723c-41a8-b5b1-cd5344b4588a' class='xr-var-data-in' type='checkbox'><label for='data-e4db40f5-723c-41a8-b5b1-cd5344b4588a' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.087893)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>sat:orbit_state</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U10</div><div class='xr-var-preview xr-preview'>&#x27;descending&#x27;</div><input id='attrs-b313f900-0020-441a-ab1c-4f6a5e04f0bb' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-b313f900-0020-441a-ab1c-4f6a5e04f0bb' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-e03eac52-750d-44b9-b02d-5da930dd05f6' class='xr-var-data-in' type='checkbox'><label for='data-e03eac52-750d-44b9-b02d-5da930dd05f6' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;descending&#x27;, dtype=&#x27;&lt;U10&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>proj:code</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U10</div><div class='xr-var-preview xr-preview'>&#x27;EPSG:32734&#x27;</div><input id='attrs-67cae0a8-8ef9-4599-a644-3b135a51cb1e' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-67cae0a8-8ef9-4599-a644-3b135a51cb1e' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-3636c39d-d39b-456c-894d-76a1b41fa034' class='xr-var-data-in' type='checkbox'><label for='data-3636c39d-d39b-456c-894d-76a1b41fa034' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;EPSG:32734&#x27;, dtype=&#x27;&lt;U10&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:product_type</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U7</div><div class='xr-var-preview xr-preview'>&#x27;S2MSI2A&#x27;</div><input id='attrs-ce799218-8d34-46c5-9a82-48a91bad41a9' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-ce799218-8d34-46c5-9a82-48a91bad41a9' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-aa72e87c-0660-4353-85c4-cb83284b1f20' class='xr-var-data-in' type='checkbox'><label for='data-aa72e87c-0660-4353-85c4-cb83284b1f20' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;S2MSI2A&#x27;, dtype=&#x27;&lt;U7&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:water_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>62.39</div><input id='attrs-cb5c549f-ac5c-4e6f-9745-e9beaf180153' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-cb5c549f-ac5c-4e6f-9745-e9beaf180153' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-73f71d46-ec71-4261-990f-cc2463ba3f88' class='xr-var-data-in' type='checkbox'><label for='data-73f71d46-ec71-4261-990f-cc2463ba3f88' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(62.385774)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:granule_id</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U62</div><div class='xr-var-preview xr-preview'>&#x27;S2B_OPER_MSI_L2A_TL_2BPS_202504...</div><input id='attrs-3bf5005b-d158-4433-b721-2e8643a342f3' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-3bf5005b-d158-4433-b721-2e8643a342f3' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-91547349-3eac-4e88-bc4b-b4c47453cc3b' class='xr-var-data-in' type='checkbox'><label for='data-91547349-3eac-4e88-bc4b-b4c47453cc3b' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;S2B_OPER_MSI_L2A_TL_2BPS_20250404T120818_A042189_T34HBH_N05.11&#x27;,
      dtype=&#x27;&lt;U62&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:not_vegetated_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>28.92</div><input id='attrs-3df7d19b-12c6-4900-b768-c139d5462b9f' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-3df7d19b-12c6-4900-b768-c139d5462b9f' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-2734c501-46ba-446b-9e9f-798fd68c0751' class='xr-var-data-in' type='checkbox'><label for='data-2734c501-46ba-446b-9e9f-798fd68c0751' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(28.92068)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:vegetation_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>5.921</div><input id='attrs-1f679834-5083-4489-a65e-e615783e889b' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-1f679834-5083-4489-a65e-e615783e889b' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-0b042049-50df-474e-8586-6ff01ae5e1da' class='xr-var-data-in' type='checkbox'><label for='data-0b042049-50df-474e-8586-6ff01ae5e1da' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(5.92114)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:datastrip_id</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U64</div><div class='xr-var-preview xr-preview'>&#x27;S2B_OPER_MSI_L2A_DS_2BPS_202504...</div><input id='attrs-b91dad4c-ee5a-4e0f-b8b4-fe814376d240' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-b91dad4c-ee5a-4e0f-b8b4-fe814376d240' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-c1fa29e9-c71e-4e9a-b43f-50d389cda61f' class='xr-var-data-in' type='checkbox'><label for='data-c1fa29e9-c71e-4e9a-b43f-50d389cda61f' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;S2B_OPER_MSI_L2A_DS_2BPS_20250404T120818_S20250404T084759_N05.11&#x27;,
      dtype=&#x27;&lt;U64&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:medium_proba_clouds_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.6404</div><input id='attrs-ca4a5b24-9818-4d2c-af9f-69cfbe8a9a81' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-ca4a5b24-9818-4d2c-af9f-69cfbe8a9a81' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-1555a590-1eb8-4221-b8b0-c54c9be029aa' class='xr-var-data-in' type='checkbox'><label for='data-1555a590-1eb8-4221-b8b0-c54c9be029aa' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.640358)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:saturated_defective_pixel_percentage</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.0</div><input id='attrs-b56d12a2-f9aa-4034-b557-84b2046d39ad' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-b56d12a2-f9aa-4034-b557-84b2046d39ad' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-43eb31db-64b7-4646-bd95-2423f0671f5b' class='xr-var-data-in' type='checkbox'><label for='data-43eb31db-64b7-4646-bd95-2423f0671f5b' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(0.)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>s2:processing_baseline</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>&lt;U5</div><div class='xr-var-preview xr-preview'>&#x27;05.11&#x27;</div><input id='attrs-16e030c5-3922-47dd-ba10-0d18076f100e' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-16e030c5-3922-47dd-ba10-0d18076f100e' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-12e9db67-93c5-4b2b-b63a-ec566ca1fa50' class='xr-var-data-in' type='checkbox'><label for='data-12e9db67-93c5-4b2b-b63a-ec566ca1fa50' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(&#x27;05.11&#x27;, dtype=&#x27;&lt;U5&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>proj:bbox</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>object</div><div class='xr-var-preview xr-preview'>{6190240.0, 309780.0, 199980.0, ...</div><input id='attrs-223054af-9136-4483-8561-0bd6ce6d497b' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-223054af-9136-4483-8561-0bd6ce6d497b' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-973fa1e0-1bc0-4819-a053-81c80f39c307' class='xr-var-data-in' type='checkbox'><label for='data-973fa1e0-1bc0-4819-a053-81c80f39c307' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array({6190240.0, 309780.0, 199980.0, 6300040.0}, dtype=object)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>title</span></div><div class='xr-var-dims'>(band)</div><div class='xr-var-dtype'>&lt;U20</div><div class='xr-var-preview xr-preview'>&#x27;Band 4 - Red - 10m&#x27; ... &#x27;Band 2...</div><input id='attrs-bf33d192-8aaf-434f-be77-9ba7b36c4301' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-bf33d192-8aaf-434f-be77-9ba7b36c4301' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-d02680e6-d128-4c25-8c78-8e3648fabb16' class='xr-var-data-in' type='checkbox'><label for='data-d02680e6-d128-4c25-8c78-8e3648fabb16' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array([&#x27;Band 4 - Red - 10m&#x27;, &#x27;Band 3 - Green - 10m&#x27;,
       &#x27;Band 2 - Blue - 10m&#x27;], dtype=&#x27;&lt;U20&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>proj:transform</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>object</div><div class='xr-var-preview xr-preview'>{0.0, 6300040.0, 10.0, 199980.0,...</div><input id='attrs-bb77d274-a74a-4e5f-955e-f4c1b7661ccf' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-bb77d274-a74a-4e5f-955e-f4c1b7661ccf' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-7b070e97-056c-4ceb-a8e1-0937b8a69f5a' class='xr-var-data-in' type='checkbox'><label for='data-7b070e97-056c-4ceb-a8e1-0937b8a69f5a' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array({0.0, 6300040.0, 10.0, 199980.0, -10.0}, dtype=object)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>proj:shape</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>object</div><div class='xr-var-preview xr-preview'>{10980}</div><input id='attrs-3ab4db0c-cc26-403f-8e6a-a4552c56bc57' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-3ab4db0c-cc26-403f-8e6a-a4552c56bc57' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-00c9be5a-46a0-40c7-99e0-91f6c7c3ab67' class='xr-var-data-in' type='checkbox'><label for='data-00c9be5a-46a0-40c7-99e0-91f6c7c3ab67' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array({10980}, dtype=object)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>gsd</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>10.0</div><input id='attrs-a73bc964-8a66-4d2c-98fe-fca1eeb67b80' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-a73bc964-8a66-4d2c-98fe-fca1eeb67b80' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-65155bf1-53e8-4ec1-9d88-0bfd61f945d8' class='xr-var-data-in' type='checkbox'><label for='data-65155bf1-53e8-4ec1-9d88-0bfd61f945d8' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(10.)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>common_name</span></div><div class='xr-var-dims'>(band)</div><div class='xr-var-dtype'>&lt;U5</div><div class='xr-var-preview xr-preview'>&#x27;red&#x27; &#x27;green&#x27; &#x27;blue&#x27;</div><input id='attrs-d49a3312-2e8c-4de8-9457-2988ad653af2' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-d49a3312-2e8c-4de8-9457-2988ad653af2' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-92412ba9-d6f0-48af-919d-3dd0fd5f850a' class='xr-var-data-in' type='checkbox'><label for='data-92412ba9-d6f0-48af-919d-3dd0fd5f850a' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array([&#x27;red&#x27;, &#x27;green&#x27;, &#x27;blue&#x27;], dtype=&#x27;&lt;U5&#x27;)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>center_wavelength</span></div><div class='xr-var-dims'>(band)</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.665 0.56 0.49</div><input id='attrs-2c9f880d-a152-47d3-a0b8-09a428c87e59' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-2c9f880d-a152-47d3-a0b8-09a428c87e59' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-3ddc57f3-2448-4021-9c40-611caad87c24' class='xr-var-data-in' type='checkbox'><label for='data-3ddc57f3-2448-4021-9c40-611caad87c24' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array([0.665, 0.56 , 0.49 ])</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>full_width_half_max</span></div><div class='xr-var-dims'>(band)</div><div class='xr-var-dtype'>float64</div><div class='xr-var-preview xr-preview'>0.038 0.045 0.098</div><input id='attrs-e2d543ca-6f22-45d7-810c-4754193dcf94' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-e2d543ca-6f22-45d7-810c-4754193dcf94' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-183f13c3-c07a-4cec-a72e-32f9e9a93c15' class='xr-var-data-in' type='checkbox'><label for='data-183f13c3-c07a-4cec-a72e-32f9e9a93c15' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array([0.038, 0.045, 0.098])</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span>epsg</span></div><div class='xr-var-dims'>()</div><div class='xr-var-dtype'>int64</div><div class='xr-var-preview xr-preview'>4326</div><input id='attrs-b36f29c3-3e89-406b-bfec-ecb2f892ba30' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-b36f29c3-3e89-406b-bfec-ecb2f892ba30' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-aaf81aec-021e-450f-aa3e-5e260d360ec7' class='xr-var-data-in' type='checkbox'><label for='data-aaf81aec-021e-450f-aa3e-5e260d360ec7' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array(4326)</pre></div></li></ul></div></li><li class='xr-section-item'><input id='section-ecf5c2e7-29de-49d6-9e10-590889325014' class='xr-section-summary-in' type='checkbox'  ><label for='section-ecf5c2e7-29de-49d6-9e10-590889325014' class='xr-section-summary' >Indexes: <span>(3)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><ul class='xr-var-list'><li class='xr-var-item'><div class='xr-index-name'><div>band</div></div><div class='xr-index-preview'>PandasIndex</div><input type='checkbox' disabled/><label></label><input id='index-69bc148f-2b57-40b6-81c1-41ddef0423dc' class='xr-index-data-in' type='checkbox'/><label for='index-69bc148f-2b57-40b6-81c1-41ddef0423dc' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(Index([&#x27;B04&#x27;, &#x27;B03&#x27;, &#x27;B02&#x27;], dtype=&#x27;object&#x27;, name=&#x27;band&#x27;))</pre></div></li><li class='xr-var-item'><div class='xr-index-name'><div>x</div></div><div class='xr-index-preview'>PandasIndex</div><input type='checkbox' disabled/><label></label><input id='index-3c8360e7-127e-4031-ae65-f279c757c1a6' class='xr-index-data-in' type='checkbox'/><label for='index-3c8360e7-127e-4031-ae65-f279c757c1a6' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(Index([17.736915050109257, 17.737025896129293,  17.73713674214933,
       17.737247588169367, 17.737358434189403,  17.73746928020944,
       17.737580126229474, 17.737690972249514,  17.73780181826955,
       17.737912664289585,
       ...
       18.953006735928927, 18.953117581948963, 18.953228427968998,
       18.953339273989034, 18.953450120009073,  18.95356096602911,
       18.953671812049144,  18.95378265806918,  18.95389350408922,
       18.954004350109255],
      dtype=&#x27;float64&#x27;, name=&#x27;x&#x27;, length=10981))</pre></div></li><li class='xr-var-item'><div class='xr-index-name'><div>y</div></div><div class='xr-index-preview'>PandasIndex</div><input type='checkbox' disabled/><label></label><input id='index-e975f971-5fa0-40c8-a247-5b27aeb6e033' class='xr-index-data-in' type='checkbox'/><label for='index-e975f971-5fa0-40c8-a247-5b27aeb6e033' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(Index([ -33.39740932131153, -33.397501700819724,  -33.39759408032792,
       -33.397686459836116,  -33.39777883934431, -33.397871218852515,
        -33.39796359836071,  -33.39805597786891,   -33.3981483573771,
         -33.3982407368853,
       ...
        -34.41090490573776, -34.410997285245955,  -34.41108966475415,
        -34.41118204426235,  -34.41127442377054,  -34.41136680327874,
        -34.41145918278694,  -34.41155156229514, -34.411643941803334,
        -34.41173632131153],
      dtype=&#x27;float64&#x27;, name=&#x27;y&#x27;, length=10981))</pre></div></li></ul></div></li><li class='xr-section-item'><input id='section-b3cdd935-56a6-4136-96fe-2a9cdbd03881' class='xr-section-summary-in' type='checkbox'  checked><label for='section-b3cdd935-56a6-4136-96fe-2a9cdbd03881' class='xr-section-summary' >Attributes: <span>(4)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><dl class='xr-attrs'><dt><span>spec :</span></dt><dd>RasterSpec(epsg=4326, bounds=(17.736915050109257, -34.411828700819726, 18.95411519612929, -33.39740932131153), resolutions_xy=(0.00011084602003642967, 9.237950819672146e-05))</dd><dt><span>crs :</span></dt><dd>epsg:4326</dd><dt><span>transform :</span></dt><dd>| 0.00, 0.00, 17.74|
| 0.00,-0.00,-33.40|
| 0.00, 0.00, 1.00|</dd><dt><span>resolution_xy :</span></dt><dd>(0.00011084602003642967, 9.237950819672146e-05)</dd></dl></div></li></ul></div></div>



### Overlaying Cube With Sentinel data


```python
import matplotlib.pyplot as plt
import xrspatial.multispectral as ms

#... (your code to generate scene_data and filtered_gdf)

# 5. Plot the Data
fig, ax = plt.subplots(figsize=(20, 16))

# Create the true-color image
sentinel_img = ms.true_color(*scene_data)  # No need for name="epsg=4326" here

# Plot the Sentinel-2 image on the existing axes
sentinel_img.plot.imshow(ax=ax, add_colorbar=False)  # Plot on 'ax', remove extra colorbar

# Plot the GeoDataFrame on the same axes
gdf_cube.plot(ax=ax, color="red", edgecolor="black", linewidth=1, alpha=0.4)

# Adjust Axes
ax.set_xlim(bbox[0], bbox[2])
ax.set_ylim(bbox[1], bbox[3])

# Labels and Title
plt.title("GeoPandas DataFrame on Sentinel-2 Background")
plt.xlabel("Longitude")
plt.ylabel("Latitude")

# Show the Plot
plt.show()
```


    
![png](output_36_0.png)
    


## EBV data cubes in NetCDF format


```python
import netCDF4 as nc
import xarray as xr


birds_file = xr.open_dataset('./data/viti_spepop_id77_20240206_v1.nc')

print(birds_file)
```

    <xarray.Dataset> Size: 26kB
    Dimensions:  (lon: 559, lat: 437, time: 1, entity: 486)
    Coordinates:
      * lon      (lon) float64 4kB 9.45e+05 9.55e+05 ... 6.515e+06 6.525e+06
      * lat      (lat) float64 3kB 5.305e+06 5.295e+06 ... 9.55e+05 9.45e+05
      * time     (time) datetime64[ns] 8B 2018-01-01
      * entity   (entity) |S37 18kB b'Gavia stellata                       ' ... ...
    Data variables:
        crs      |S1 1B ...
    Attributes: (12/38)
        Conventions:                CF-1.8, ACDD-1.3, EBV-1.0
        naming_authority:           The German Centre for Integrative Biodiversit...
        history:                    EBV netCDF created using ebvcube, 2024-02-06
        ebv_vocabulary:             https://portal.geobon.org/api/v1/ebv
        ebv_cube_dimensions:        lon, lat, time, entity
        keywords:                   ebv_class: Species populations, ebv_name: Spe...
        ...                         ...
        geospatial_lat_units:       meter
        time_coverage_start:        2013-01-01
        time_coverage_end:          2018-12-31
        time_coverage_resolution:   P0000-00-00
        date_issued:                2024-02-12
        comment:                    List of species: https://cdr.eionet.europa.eu...



```python
def print_netcdf_structure(nc_file_path):
  """Prints the structure (groups, variables, and their paths) of a NetCDF file.

  Args:
    nc_file_path: Path to the NetCDF file.
  """
  def print_group_structure(group, path=""):
    """Recursively prints the structure of a group within the NetCDF file."""
    for var_name in group.variables:
      print(f"{path}/{var_name}")  # Print variable path
    for group_name in group.groups:
      subgroup = group.groups[group_name]
      print_group_structure(subgroup, f"{path}/{group_name}")  # Recursively explore subgroups

  with nc.Dataset(nc_file_path, 'r') as nc_file:
    print_group_structure(nc_file)  # Start with the root group

# Example usage:
nc_file_path = './data/viti_spepop_id77_20240206_v1.nc'
print_netcdf_structure(nc_file_path)
```

    /lon
    /lat
    /time
    /crs
    /entity
    /metric_1/ebv_cube



```python
print(birds_file.variables)
```

    Frozen({'lon': <xarray.IndexVariable 'lon' (lon: 559)> Size: 4kB
    array([ 945000.,  955000.,  965000., ..., 6505000., 6515000., 6525000.])
    Attributes:
        long_name:      lon
        standard_name:  projection_x_coordinate
        axis:           X
        units:          meter, 'lat': <xarray.IndexVariable 'lat' (lat: 437)> Size: 3kB
    array([5305000., 5295000., 5285000., ...,  965000.,  955000.,  945000.])
    Attributes:
        long_name:      lat
        standard_name:  projection_y_coordinate
        axis:           Y
        units:          meter, 'time': <xarray.IndexVariable 'time' (time: 1)> Size: 8B
    array(['2018-01-01T00:00:00.000000000'], dtype='datetime64[ns]')
    Attributes:
        long_name:  time
        axis:       T, 'crs': <xarray.Variable ()> Size: 1B
    [1 values with dtype=|S1]
    Attributes:
        spatial_ref:                     PROJCRS["ETRS89-extended / LAEA Europe",...
        GeoTransform:                    940000 10000 0.0 5310000 0.0 -10000
        grid_mapping_name:               lambert_azimuthal_equal_area
        latitude_of_projection_origin:   52.0
        longitude_of_projection_origin:  10.0
        false_easting:                   4321000.0
        false_northing:                  3210000.0
        semi_major_axis:                 6378137.0
        inverse_flattening:              298.257223563
        longitude_of_prime_meridian:     0.0
        long_name:                       CRS definition, 'entity': <xarray.IndexVariable 'entity' (entity: 486)> Size: 18kB
    array([b'Gavia stellata                       ',
           b'Gavia arctica                        ',
           b'Tachybaptus ruficollis               ', ...,
           b'Accipiter gentilis all others        ',
           b'Melanitta nigra s. str.              ',
           b'Sylvia subalpina                     '], dtype='|S37')
    Attributes:
        units:                           1
        ebv_entity_type:                 Species
        ebv_entity_scope:                Bird species listed under the Art. 12 of...
        ebv_entity_classification_name:  Species names as accepted by the Birds D...
        ebv_entity_classification_url:   https://cdr.eionet.europa.eu/help/birds_...
        long_name:                       entity})



```python
time = birds_file.variables['time']
print(time)

print(birds_file['entity'])
```

    <xarray.IndexVariable 'time' (time: 1)> Size: 8B
    array(['2018-01-01T00:00:00.000000000'], dtype='datetime64[ns]')
    Attributes:
        long_name:  time
        axis:       T
    <xarray.DataArray 'entity' (entity: 486)> Size: 18kB
    array([b'Gavia stellata                       ',
           b'Gavia arctica                        ',
           b'Tachybaptus ruficollis               ', ...,
           b'Accipiter gentilis all others        ',
           b'Melanitta nigra s. str.              ',
           b'Sylvia subalpina                     '], dtype='|S37')
    Coordinates:
      * entity   (entity) |S37 18kB b'Gavia stellata                       ' ... ...
    Attributes:
        units:                           1
        ebv_entity_type:                 Species
        ebv_entity_scope:                Bird species listed under the Art. 12 of...
        ebv_entity_classification_name:  Species names as accepted by the Birds D...
        ebv_entity_classification_url:   https://cdr.eionet.europa.eu/help/birds_...
        long_name:                       entity



```python
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import xarray as xr
import numpy as np
from pyproj import Transformer
from matplotlib.colors import ListedColormap, BoundaryNorm

# --- Load Dataset Efficiently ---
birds_file = xr.open_dataset(
    './data/viti_spepop_id77_20240206_v1.nc',
    group="metric_1",
    chunks={'entity': 1, 'time': 1}  # Load only one entity/time slice at a time
)

# --- Select Target Species and Time ---
species_index = 150  # Change to the species index you need
time_index = 0  # Change to the desired time index

# Extract only the required slice
species_data_subset = birds_file['ebv_cube'].sel(entity=species_index, time=time_index).compute()

# Convert to a 2D array
species_distribution_2d = np.squeeze(species_data_subset)

# --- Load Longitude and Latitude (Only Once) ---
with xr.open_dataset('./data/viti_spepop_id77_20240206_v1.nc') as ds:
    lon = ds['lon'].values  # 1D array (size: 559)
    lat = ds['lat'].values  # 1D array (size: 437)

# --- Create Meshgrid Efficiently ---
lon_grid, lat_grid = np.meshgrid(lon, lat)

# --- Efficient Coordinate Transformation ---
transformer = Transformer.from_crs("epsg:3035", "epsg:4326", always_xy=True)

# Transform the entire 2D meshgrid
lon_deg, lat_deg = transformer.transform(lon_grid, lat_grid)

# --- Create the Plot ---
fig = plt.figure(figsize=(10, 6))
ax = fig.add_subplot(1, 1, 1, projection=ccrs.PlateCarree())

# Add map features
ax.coastlines()
ax.add_feature(cfeature.LAND, edgecolor='black', facecolor='lightgray')

# --- 🔹 Fix: Use Discrete Colormap Without Color Bar ---
unique_values = np.unique(species_distribution_2d)

# If only one value, choose a single solid color
if len(unique_values) == 1:
    cmap = ListedColormap(["red"])  # Single-color for uniform data
    norm = None
else:
    cmap = ListedColormap(["white", "blue"])  # Adjust colors as needed
    norm = BoundaryNorm([0, 0.5, 1], cmap.N)

# --- 🔹 Fix: Use `shading="nearest"` to Ensure Correct Grid Alignment ---
cs = ax.pcolormesh(
    lon_deg, lat_deg, species_distribution_2d,
    transform=ccrs.PlateCarree(),
    cmap=cmap,
    norm=norm,
    shading='nearest'  # Prevents visual distortion
)

# --- 🔹 Completely Remove Color Bar ---
# No `fig.colorbar(cs)`, so no scale bar will be shown

# --- Get the Species Name Efficiently ---
with xr.open_dataset('./data/viti_spepop_id77_20240206_v1.nc') as ds:
    species_name = ds['entity'].values[species_index].decode('utf-8').strip()

# --- Final Plot Customization ---
ax.set_title(f"Species {species_name} Distribution (10x10 km grid) at time {birds_file['time'].values[time_index].item()}")
ax.set_xlabel("Longitude")
ax.set_ylabel("Latitude")

# --- 🔹 Fix: Add Grid Lines to Show Exact 10x10 km Cells ---
gridlines = ax.gridlines(draw_labels=True, linestyle="--", linewidth=0.5, color="black", alpha=0.5)

# Show the plot
plt.show()

```


    
![png](output_42_0.png)
    

