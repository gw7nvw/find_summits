**Find summits from a raster DEM**

The following uses Ruby on Rails, running against a PostGIS database called summits.

You will need gdal-bin >3.0



**Preprocessing**

This code uses vector contour polygons, not a raster DEM, so you need to convert your DEM to 1m contour polygons.

**DEM**

get max elevation in the DEM
```
gdalinfo BP.tif -stats
```

Then process 1m at a time - can run on multiple cores in separate windows (example uses 499 max elevation)
```
for i in {1..499}
do
  echo "Extract Contour $i"
  gdal_contour -fl $i -amin ele -p ../TM.tif temp1.shp
  ogr2ogr -where ele="$i" tm_cont_$i.shp temp1.shp
  rm temp1.*
done
```

convert multipart to singlepart
```
for file in `ls *.shp`
do
 echo $file
 ogr2ogr -explodecollections single/$file $file
done
```

combine in a single file:
```
ogrmerge.py -single -f GPKG -o merged/mb_cont.gpkg single/*.shp
```

import Contours to QGIS
```
ogr2ogr -f PostgreSQL "PG:dbname=summits" -nln contour -t_srs "EPSG:4326" /mnt/volume_sgp1_01/contour/merged/contour.gpkg
```

**EXTENT BOUNDARY**

This is required to detect when the analysis reachs the limits of the DEM
If you have a polygon already for your DEM limit then use that and just follow the last 4 steps.  Otherwise use the 0m contour as follows.

You will have to do this manually in a GIS package or usign GDAL
* copy 0m contour into new layer
* dissolve polygons
* convert to a meter projection
* buffer to -10m (10m within the data extent)
* convert to lines
* convert to singleparts
* convert to EGSP:4326
* import into PostGIS
```
ogr2ogr -f PostgreSQL "PG:dbname=summits" -nln extent -t_srs "EPSG:4326" /mnt/volume_sgp1_01/contour/extent.shp
```

**Finding summits**

This will populate the table peaks with all summits of prominence >30m.  Change MIN_PROMINENCE in app/model/peak.rb to adjust this minimum

In the rails console:
```
Peak.add_all_peaks
```

**Finding saddles**

This will attempt to find the saddles between each peak and their highest neighbour.  It relies on the saddle lying on the shortest line connecting the two contours 1m above the saddle.  Where that is not the case, it will fail and saddle_status will be "not_found".

```
Peak.add_all_saddles
```

You can then go through and manually populate the 5-10% of saddles that are not found automatically.  We tried various more reliable ways of finding saddles, but they took way too long on the size of DEM we were using.

**Export results**

```
pgsql2shp  -u <user> -P <passwd>  -f test.shp  summits peaks
```



