# TomogramAnalysis
Igor Pro procedures for analysis of microtubules in electron tomograms

The main procedure file is `MTLoader.ipf`.

- prepare separate `*.pxp` files for each tomogram. See [Note 1 and Note 2](#notes)
- execute `MTLoader()`, point Igor at the directory containing all pxps
- all files will load and be converted to properly formatted MT waves
- execute `BundleStats()`. This will make heat maps for all MT bundles that were loaded. [Note 3](#notes)
- the resulting view is tiled. You can use `ShowMe()` to simplify the view. See [Note 4](#notes)
- use `PullOut()` to analyse the angles of all MTs in the bundle. See [Note 5](#notes)


Compatible with IgorPro 6.3x and 7.0

--

An earlier version of this code, which predates this repo, was used in [Nixon *et al.* 2015](https://elifesciences.org/lookup/doi/10.7554/eLife.07635.001). This is reproduced as `Nixon2015Code.rtf` a lexed version of the code for readability.

Two procedure files are included but not needed for analysis.

- `MTAngleProcedures.ipf`
- `MTCluster.ipf`

--

###Notes
1. Each MT is a 7 point wave named wave0,wave1,... Point 0 is the MT ID number 1,2,... Points 1-3 are the x,y,z, coordinates of the MT at the bottom of the tomogram. Points 4-6 are the x,y,z coordinates of the MT at the top of the tomogram.
2. To use functions downstream, it is best to label your files logically. If there is control vs drug1 vs drug 2 and warm vs cold, i.e. 3 x 2 = 6 conditions; then label files logically. e.g. control\_warm\_2.pxp, drug1\_cold\_3.pxp
3. In addition to the heatmaps and colour coded MT plots. A table is generated showing how many MTs per bundle, the area of a convex hull containing all MTs in a bundle and the resultant density.
4. The input is a string containing wildcards to match the windows to be shown. `ShowMe("img_GFP*")` will show all GFP heatmaps, `ShowMe("map_GFP*")` will show all GFP colour coded MT maps. `ShowMe("*")` will show everything.
5. The procedure will do the rotation normalisation and make the waves to show the intersection of vectors with an XY plane at 100 nm in Z. Call using `PullOut("control;drug1;drug2;",expB="warm;cold;")`.