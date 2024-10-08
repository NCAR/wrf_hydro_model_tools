############################################################
# R script to create spatial parameter files from TBLs.
# Usage: Rscript create_soilproperties.R 
# Developed: 11/11/2016, A. Dugger
# Updated: 07/23/2017, New functionality to create HYDRO2DTBL.nc, A. Dugger
#          03/02/2020, Update MPTABLE.TBL read for new format in WRF-Hydro v5.2.x, A. Dugger
#          10/01/2024, Updates for v5.3, A. Dugger
############################################################

# Update relevant arguments below.

#### Input geogrid:
geoFile <- "geo_em.d01.nc"

#### Input parameter tables:
soilParamFile <- "SOILPARM.TBL"
mpParamFile <- "MPTABLE.TBL"
genParamFile <- "GENPARM.TBL"
hydParamFile <- "HYDRO.TBL"

#### Output files to create: 
# IMPORTANT: The netcdf files below will be overwritten if they exist!
slpropFile <- "soil_properties.nc"
hyd2dFile <- "hydro2dtbl.nc"

#### Update texture class in geogrid?
# Note that if TRUE, the script will overwrite the geogrid file specified above.
updateTexture <- FALSE

#### Category to fill in for soil class if a cell is water in the soil layer but NOT water in the land cover layer:
# If the script encounters a cell that is classified as land in the land use field (LU_INDEX) but is 
# classified as a water soil type, it will replace the soil type with the value you specify below.
# If updateTexture is TRUE, these chages will be propagated to the geogrid. If not, they are just
# used in parameter assignment. 
# Ideally there are not very many of these, so you can simply choose the most common soil type in 
# your domain. Alternatively, you can set to a "bad" value (e.g., -8888) to see how many of these 
# conflicts there are. If you do this DO NOT RUN THE MODEL WITH THESE BAD VALUES. Instead, fix them 
# manually with a neighbor fill or similar fill algorithm.
soilFillVal <- 3

#### Hard-wire urban soil properties in hydro 2d table?
# Some soil parameters are hard-coded to preset values in NoahMP and WRF-Hydro for urban land cover cells.
# If you want to show these in your hyd2dFile parameter file, set this to TRUE. If you want to show
# default parameters, set to FALSE. There should be no answer differences either way.
setUrban <- FALSE

#### Land cover classification system?
# Options: USGS or MODIS
landClass <- "USGS"

#### Number of soil layers (e.g., 4)
# This number should be consistent with the nsoil in the geogrid IF you choose the updateTexture option.
nsoil <- 4

#######################################################
# Do not update below here.
#######################################################

library(ncdf4)

# Soil Properties
nameLookupSoil <- list(smcref="REFSMC", dwsat="SATDW", smcdry="DRYSMC", smcwlt="WLTSMC",
                   bexp="BB", dksat="SATDK", psisat="SATPSI", quartz="QTZ",
                   refdk="REFDK", refkdt="REFKDT", slope="SLOPE", smcmax="MAXSMC",
                   cwpvt="CWPVT", vcmx25="VCMX25", mp="MP", hvt="HVT", mfsno="MFSNO",
                   rsurfexp="RSURF_EXP", rsurfsnow="RSURF_SNOW", scamax="SCAMAX",
                   ssi="SSI", snowretfac="SNOW_RET_FAC", tau0="TAU0",
                   AXAJ="AXAJ", BXAJ="BXAJ", XXAJ="XXAJ")
var3d <- c("smcref", "dwsat", "smcdry", "smcwlt", "bexp", "dksat", "psisat", "quartz", "smcmax")
# Hydro 2D Table
nameLookupHyd <- list(SMCMAX1="smcmax", SMCREF1="smcref", SMCWLT1="smcwlt", 
                   OV_ROUGH2D="OV_ROUGH2D", LKSAT="dksat", NEXP="NEXP")
# MPTABLE parsing
if (landClass == "USGS") mpskip <- 48
if (landClass == "MODIS") mpskip <- 191

#### Create new soil properties file with fill values

cmd <- paste0("ncks -O -4 -v HGT_M ", geoFile, " ", slpropFile)
print(cmd)
system(cmd, intern=FALSE)
ncid <- nc_open(slpropFile, write=TRUE)
sndim <- ncid$dim[['south_north']]
wedim <- ncid$dim[['west_east']]
soildim <- ncdim_def("soil_layers_stag", "", vals=1:nsoil, create_dimvar=FALSE)
timedim <- ncid$dim[['Time']]
for (i in names(nameLookupSoil)) {
   message(i)
   if (i %in% var3d) {
      vardef <- ncvar_def(i, "", list(wedim, sndim, soildim, timedim), missval=-9999.0)
   } else {
      vardef <- ncvar_def(i, "", list(wedim, sndim, timedim), missval=-9999.0)
   }
   ncid <- ncvar_add(ncid, vardef)
}
nc_close(ncid)
cmd <- paste0("ncks -O -x -v HGT_M ", slpropFile, " ", slpropFile)
print(cmd)
system(cmd, intern=FALSE)


#### Create new hydro2d file with fill values

cmd <- paste0("ncks -O -4 -v HGT_M ", geoFile, " ", hyd2dFile)
print(cmd)
system(cmd, intern=FALSE)
ncid <- nc_open(hyd2dFile, write=TRUE)
sndim <- ncid$dim[['south_north']]
wedim <- ncid$dim[['west_east']]
for (i in names(nameLookupHyd)) {
   message(i)
   vardef <- ncvar_def(i, "", list(wedim, sndim), missval=-9999.0)
   ncid <- ncvar_add(ncid, vardef)
}
nc_close(ncid)
cmd <- paste0("ncks -O -x -v HGT_M ", hyd2dFile, " ", hyd2dFile)
print(cmd)
system(cmd, intern=FALSE)

#### Read parameter tables

# SOILPARM
if (exists("soilParamFile") && !is.null(soilParamFile)) {
   soltab <- read.table(soilParamFile, header=FALSE, skip=3, sep=",", comment.char="!",
                blank.lines.skip=TRUE, strip.white=TRUE, nrows=19, stringsAsFactors=FALSE)
   solhead <- read.table(soilParamFile, header=FALSE, skip=2, sep=" ", nrows=1, 
                stringsAsFactors=FALSE, quote = "", strip.white=TRUE)
   solhead <- solhead[!is.na(solhead)]
   solhead <- solhead[2:(length(solhead)-1)]
   solhead <- gsub("[']", "", solhead)
   names(soltab) <- c("solID", solhead, "solName")
} else {
   message("No soil parameter file found. Exiting.")
   q("no")
}

# MPTABLE
if (exists("mpParamFile") && !is.null(mpParamFile)) {
   # Veg type params
   mptab <- read.table(mpParamFile, header=FALSE, skip=mpskip, sep=",", comment.char="!",
                            blank.lines.skip = TRUE, strip.white = TRUE, nrows=80,
                            stringsAsFactors=FALSE)
   SepString <- function(x) {trimws(unlist(strsplit(x, split="="))[1])}
   tmp1 <- apply(as.data.frame(mptab$V1), 1, SepString)
   SepString <- function(x) {as.numeric(trimws(unlist(strsplit(x, split="="))[2]))}
   tmp2 <- apply(as.data.frame(mptab$V1), 1, SepString)
   mptab$V1 <- tmp2  
   rownames(mptab) <- tmp1
   if (landClass == "USGS") mptab$V28 <- NULL
   if (landClass == "MODIS") mptab$V21 <- NULL
   mptab <- as.data.frame(t(mptab))
   mptab$vegID <- seq(1, nrow(mptab))
   # Global params
   gparmLine <- grep("RSURF_EXP", readLines(mpParamFile), value = TRUE)
   rexpVal <- unlist(strsplit(gsub(" ", "", unlist(strsplit(gparmLine, "!"))[1]), "="))[2]
   gparmLine <- grep("RSURF_SNOW", readLines(mpParamFile), value = TRUE)
   rsnowVal <- unlist(strsplit(gsub(" ", "", unlist(strsplit(gparmLine, "!"))[1]), "="))[2]
   # This param is new for v5.3 so set to 1.0 if not found for backward compatibility with v5.2
   gparmLine <- grep("SCAMAX", readLines(mpParamFile), value = TRUE)
   if (length(gparmLine)>0) { 
     scaVal <- unlist(strsplit(gsub(" ", "", unlist(strsplit(gparmLine, "!"))[1]), "="))[2]
   } else {
     scaVal <- 1.0
   }
   gparmLine <- grep("SSI", readLines(mpParamFile), value = TRUE)
   ssiVal <- unlist(strsplit(gsub(" ", "", unlist(strsplit(gparmLine, "!"))[1]), "="))[2]
   gparmLine <- grep("SNOW_RET_FAC", readLines(mpParamFile), value = TRUE)
   snowretVal <- unlist(strsplit(gsub(" ", "", unlist(strsplit(gparmLine, "!"))[1]), "="))[2]
   gparmLine <- grep("TAU0", readLines(mpParamFile), value = TRUE)
   tauVal <- unlist(strsplit(gsub(" ", "", unlist(strsplit(gparmLine, "!"))[1]), "="))[2]

   mpglobtab <- list(RSURF_EXP=as.numeric(rexpVal), RSURF_SNOW=as.numeric(rsnowVal),
                     SCAMAX=as.numeric(scaVal), SSI=as.numeric(ssiVal),
                     SNOW_RET_FAC=as.numeric(snowretVal), TAU0=as.numeric(tauVal))
} else {
   message("No MP parameter file found. Exiting.")
   q("no")
}

# GENPARM
if (exists("genParamFile") && !is.null(genParamFile)) {
   gendump <- readLines(genParamFile)
   slopeVal <- as.numeric(gendump[which(gendump=="SLOPE_DATA")+2])
   refkdtVal <- as.numeric(gendump[which(gendump=="REFKDT_DATA")+1])
   refdkVal <- as.numeric(gendump[which(gendump=="REFDK_DATA")+1])
   gentab <- list(REFDK=refdkVal, REFKDT=refkdtVal, SLOPE=slopeVal)
} else {
   message("No GENPARM parameter file found. Exiting.")
   q("no")
}

# HYDPARM
if (exists("hydParamFile") && !is.null(hydParamFile)) {
   hydhead <- readLines(hydParamFile, n=1)
   pcount <- as.integer(unlist(strsplit(stringr::str_trim(hydhead), split=" "))[1])
   hydtab <- read.table(hydParamFile, header=FALSE, skip=2, sep=",", comment.char="!",
                            blank.lines.skip = TRUE, strip.white = TRUE, nrows=pcount,
                            stringsAsFactors=FALSE)
   names(hydtab) <- c("OV_ROUGH2D", "descrip")
   hydtab$vegID <- seq(1, pcount)
} else {
   message("No HYDRO parameter file found. Exiting.")
   q("no")
}


#### Spatial soil parameter files

# Get 2D fields
if (exists("geoFile") && !is.null(geoFile)) {
   geoin <- nc_open(geoFile)
   vegmap <- ncvar_get(geoin, "LU_INDEX")
   solmap <- ncvar_get(geoin, "SCT_DOM")
   # Get some attributes
   vegWater <- ncatt_get(geoin, 0)[["ISWATER"]]
   vegLake <- ncatt_get(geoin, 0)[["ISLAKE"]]
   soilWater <- ncatt_get(geoin, 0)[["ISOILWATER"]]
   maxSoilClass <- geoin$dim[["soil_cat"]]$len
   vegUrban <- ncatt_get(geoin, 0)[["ISURBAN"]]
   message(paste0("Geogrid attributes: vegWater=", vegWater, " vegLake=", vegLake, " soilWater=", soilWater, " maxSoilClass=", maxSoilClass))
   vegmap[vegmap == vegLake] <- vegWater
   solmap[vegmap != vegWater & solmap == soilWater] <- soilFillVal
   solmap[vegmap == vegWater] <- soilWater
   nc_close(geoin)
} else {
   message("No geogrid file found. Exiting.")
   q("no")
}

# Get new soil props file
ncid <- nc_open(slpropFile, write=TRUE)
paramList <- names(ncid$var)

# Loop through params and update
message(paste0("Updating: ", slpropFile))
for (param in paramList) {
   paramName <- nameLookupSoil[[param]]
   print(paste0("Processing ", param))
   if (!is.null(paramName)) {
      if (paramName %in% names(soltab)) {
         print(paste("Updating soil parameters:", param, " ", paramName))
         ncvar <- ncvar_get(ncid, param)
         pnew <- solmap
         pnew[!(pnew %in% soltab[,"solID"])] <- (-9999)
         pnew <- plyr::mapvalues(pnew, from=soltab$solID, to=soltab[,paramName])
         if (param %in% var3d) {
           pnew3d <- array(rep(pnew, dim(ncvar)[3]), dim=dim(ncvar))
           pnew3d[pnew3d < (-9998)] <- ncvar[pnew3d < (-9998)]
           ncvar_put(ncid, param, pnew3d)
         } else {
           pnew[pnew < (-9998)] <- ncvar[pnew < (-9998)]
           ncvar_put(ncid, param, pnew)
         }
      } else if (paramName %in% names(mptab)) {
         print(paste("Updating MP parameters:", param, " ", paramName))
         ncvar <- ncvar_get(ncid, param)
         pnew <- vegmap
         pnew[!(pnew %in% mptab[,"vegID"])] <- (-9999)
         pnew <- plyr::mapvalues(pnew, from=mptab$vegID, to=mptab[,paramName])
         pnew[pnew < 0] <- ncvar[pnew < 0]
         ncvar_put(ncid, param, pnew)
      } else if (paramName %in% names(gentab)) {
         print(paste("Updating GEN parameters:", param, " ", paramName))
         ncvar <- ncvar_get(ncid, param)
         ncvar[is.na(ncvar)] <- 0
         pnew <- ncvar*0 + gentab[[paramName]]
         ncvar_put(ncid, param, pnew)
      } else if (paramName %in% names(mpglobtab)) {
         print(paste("Updating global MP  parameters:", param, " ", paramName))
         ncvar <- ncvar_get(ncid, param)
         ncvar[is.na(ncvar)] <- 0
         pnew <- ncvar*0 + mpglobtab[[paramName]]
         ncvar_put(ncid, param, pnew)
      }
   }
}
nc_close(ncid)

# Update texture class variables
if (updateTexture) {
   message("Updating texture classes")
   lyrList <- list(top=list(indx=1, splitlyr="SOILCTOP", mglyr="SCT_DOM"), bot=list(indx=nsoil, splitlyr="SOILCBOT", mglyr="SCB_DOM"))
   ncid <- nc_open(geoFile, write=TRUE)
   for (lyr in names(lyrList)) {
      # Get relevant variable/layer
      soil_texture <- ncvar_get(ncid, lyrList[[lyr]][["mglyr"]])
      soil_texture <- soil_texture*0-9999
      i <- lyrList[[lyr]][["indx"]]
      soil_texture <- solmap
      # Place new merged var
      ncvar_put(ncid, lyrList[[lyr]][["mglyr"]], soil_texture)
      # Calculate and place split layer (assumes 100% for specified class)
      soltyps <- seq(1, maxSoilClass, 1)
      for (typ in soltyps) {
         tmp <- plyr::mapvalues(soil_texture, c(typ), c(-100))
         tmp <- ifelse(tmp<0, 1, 0)
         ncvar_put(ncid, lyrList[[lyr]][["splitlyr"]],  tmp, start=c(1,1,typ,1), count=c(-1,-1,1,-1))
      }
   }
   nc_close(ncid)
}

# Update the soil map in case changes above
if (exists("geoFile") && !is.null(geoFile)) {
   geoin <- nc_open(geoFile)
   vegmap <- ncvar_get(geoin, "LU_INDEX")
   solmap <- ncvar_get(geoin, "SCT_DOM")
   nc_close(geoin)
}

# Get new hydro2d file
message(paste0("Updating: ", hyd2dFile))
ncid <- nc_open(hyd2dFile, write=TRUE)
paramList <- names(ncid$var)

# Loop through params and update
for (param in paramList) {
   paramNameHyd <- nameLookupHyd[[param]]
   paramNameSoil <- nameLookupSoil[[paramNameHyd]]
   print(paste0("Processing ", param))
   if (!is.null(paramNameHyd)) {
      if (!is.null(paramNameSoil) && paramNameSoil %in% names(soltab)) {
         print(paste("Updating HYDRO soil parameters:", param, " ", paramNameHyd, " ", paramNameSoil))
         ncvar <- ncvar_get(ncid, param)
         pnew <- solmap
         pnew[!(pnew %in% soltab[,"solID"])] <- (-9999)
         # Manually force soil and water cells to match
         pnew[vegmap == vegWater] <- soilWater
         pnew <- plyr::mapvalues(pnew, from=soltab$solID, to=soltab[,paramNameSoil])
         pnew[pnew < (-9998)] <- ncvar[pnew < (-9998)]
         # Manually make some changes to urban cells to match hydro code
         if ( setUrban ) {
            if (param == "SMCMAX1") pnew[vegmap == vegUrban & solmap != soilWater] <- 0.45
            if (param == "SMCREF1") pnew[vegmap == vegUrban & solmap != soilWater] <- 0.42
            if (param == "SMCWLT1") pnew[vegmap == vegUrban & solmap != soilWater] <- 0.40
         }
         ncvar_put(ncid, param, pnew)
      } else if (paramNameHyd %in% names(hydtab)) {
         print(paste("Updating HYDRO veg parameters:", param, " ", paramNameHyd))
         ncvar <- ncvar_get(ncid, param)
         pnew <- vegmap
         pnew[!(pnew %in% hydtab[,"vegID"])] <- (-9999)
         # Manually force soil and water cells to match
         pnew[solmap == soilWater] <- vegWater
         pnew <- plyr::mapvalues(pnew, from=hydtab$vegID, to=hydtab[,paramNameHyd])
         pnew[pnew < 0] <- ncvar[pnew < 0]
         ncvar_put(ncid, param, pnew)
      } else if (paramNameHyd == "NEXP") {
         # Setting this to a global initial value of 1.0
         print(paste("Updating HYDRO global parameters:", param, " ", paramNameHyd))
         ncvar <- ncvar_get(ncid, param)
         ncvar[,] <- 1.0
         ncvar_put(ncid, param, ncvar)
      }
   }
}
nc_close(ncid)


q("no")

