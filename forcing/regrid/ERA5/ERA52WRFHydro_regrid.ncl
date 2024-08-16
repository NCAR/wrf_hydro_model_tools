;----------------------------------------------------------------------
; Name    : ERA52WRFHydro_regrid.ncl
; Purpose : This is an NCL script that uses ESMF utilities to perform regridding of various  
;           data fields to a WRF-Hydro domain.
;           Important notes:
;           1) This script is currently configured to use the bilinear interpolation option for all forcing 
;              fields.  Should the user desire to use a different interpolation option, the name for the
;              corresponding weight file should be added to user settings and the weight files for each 
;              variable adjusted appropriately.
; Example Usage   : ncl 'srcFileName="era5.*.nc"' 'dstGridName="geo_em.d01.nc"' ERA52WRFHydro_regrid.ncl
;           srcFileName = filename pattern of the souce ERA5 files.
;                         e.g., "era5.2023080100.nc", "era5.20230801*.nc" , ...
;           dstGridName = name of file that contains the destination (WRF-Hydro) grid
; Dr.Haiqing SONG 23 Sep 2023
;----------------------------------------------------------------------
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/ut_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

;----------------------------------------------------------------------
; User settings
;----------------------------------------------------------------------

  ;---------------------------------------------------------------;
  ; Set input and output file directories.                        ;
  ;---------------------------------------------------------------;
  dirm    = "./input_files/"       ; directory where source forcing data resides
  outdir  = "./output_files/"      ; directory where regridded forcing data will be placed. set to dirm for overwriting the original file
  ;---------------------------------------------------------------;
  ; Source model data tination grid filenames.                    ;
  ;---------------------------------------------------------------;
  dt=3600.0   ;forcing data timestep in seconds...
  ;---------------------------------------------------------------;
  ; Weight filenames for regridding                               ;
  ;---------------------------------------------------------------;
  wgtFileName_conserve = "./ERA52WRFHydro_weight_conserve.nc"

  ;---------------------------------------------------------------;
  ; Data field names from the source file to be regridded         ;
  ;---------------------------------------------------------------;
   P_varname = "SP_GDS0_SFC";Pa
   T_varname = "2T_GDS0_SFC";k
   U_varname = "10U_GDS0_SFC";m s**-1
   V_varname = "10V_GDS0_SFC";m s**-1
   Q_varname = "2D_GDS0_SFC";k into kg/kg
   PCP_varname  = "TP_GDS0_SFC_acc1h" ;m
   DSWR_varname = "STRM_GDS0_SFC_ave1h";W m**-2 s
   DLWR_varname = "V_POT_GDS0_SFC_ave1h";W m**-2 s
;----------------------------------------------------------------------
; read in source and destination grid netCDF files
;----------------------------------------------------------------------

  if ( .not.isfilepresent( dstGridName ) ) then
     print( " ... source grid file not found : "+ dstGridName )
     exit
  else 
;      dstGridName = "./geo_em.d01.nc"
  end if

;---  destination grid data
  dstfile     = addfile( dstGridName ,"r")
  dlon2d=dstfile->XLONG_M(0,:,:)
  dlat2d=dstfile->XLAT_M(0,:,:)
  dims=dimsizes(dlat2d)

  flag=0    ;WRF - flag for removing accum precip...

;----------------------------------------------------------------------
; Open source data files to be regridded...
;----------------------------------------------------------------------
  system("mkdir "+outdir)

  datfils = systemfunc ("ls "+dirm+srcFileName)    ;list of file names
  num_datfils     = dimsizes(datfils)

  do ifil = 0,num_datfils-1,1   ; loop through datafiles one at a time
   
      suffix = isStrSubset( datfils(ifil), ".grib" ) ; check if the input filename has .grib suffix
      if (suffix) then
         datfile = addfile( datfils(ifil), "r")
      else
      print( suffix)
         datfile = addfile( datfils(ifil)+".grib", "r")
      end if

      print( " ... Open input file : "+ datfils(ifil) )
   
     ;----------------------------------------------------------------------
     ; Parse time from filename : era5.2019011300.nc
     ;----------------------------------------------------------------------
      strs = str_split( datfils(ifil), "." )
      date_str = strs(1)
      dtime_map = (/4,2,2,2/)
      date_vec = str_split_by_length( date_str, dtime_map)
      print( date_vec )

      Times_str = date_vec(0)+"-"+date_vec(1)+"-"+date_vec(2)+"_"+date_vec(3)+":00:00"
      new_string = str_strip(Times_str)
      Times = stringtochar( new_string )
      Times!0 = "DateStrLen"

      valid_time = cd_inv_calendar(toint(date_vec(0)), toint(date_vec(1)), toint(date_vec(2)), toint(date_vec(3)), toint(0) ,toint(0) ,"seconds since 2008-01-01 00:00:00", 0)
      valid_time!0 = "Time"

     ;----------------------------------------------------------------------
     ; Open output file
     ;----------------------------------------------------------------------
      ncfile= outdir + date_str+".LDASIN_DOMAIN1.nc"
      if ( isfilepresent( ncfile ) ) then
         system ("/bin/rm "+ncfile)
      end if
      ncdf= addfile(ncfile,"c")
      filedimdef( ncdf ,"Time",-1,True)
      ncdf->lat = dlat2d   ;output lat
      ncdf->lon = dlon2d   ;output lon
      ncdf->Times = Times  ;output times
      ncdf->valid_time = valid_time

globalAtt = True
globalAtt@missing_value = 1.e+20 ; 
globalAtt@_FillValue = 1.e+20 ; -9999;
globalAtt@data_source="ERA5 hourly reanlysis"
globalAtt@Center="Ecological and Agricultural Meteorology Center of Inner Mongolia/IMWB/CMA, Hohhot"
globalAtt@Datasets_Leader = "Dr.Haiqing SOONG,IMWB/CMA,E-mail:haiqingsong2010@163.com"
fileattdef( ncdf, globalAtt )      
     ;----------------------------------------------------------------------
     ;  Processing...no further mods should be required...
     ;----------------------------------------------------------------------
     do v=1,8
     
        if (v.eq.1) then
           var = datfile->$T_varname$
           wgtFileName = wgtFileName_conserve
           var@description = "Temperature at 2m"
           var@units       = "K"
        end if
        if (v.eq.2) then
           wgtFileName = wgtFileName_conserve
           varP = datfile->$P_varname$
           varD = datfile->$Q_varname$
           var = mixhum_ptd (varP, varD, 2) 
           var@description = "Specific Huminity at 2m"
           var@units       = "kg kg^-1"
        end if
        if (v.eq.3) then
           var = datfile->$P_varname$
           wgtFileName = wgtFileName_conserve
           var@description = "Surface Pressure"
           var@units       = "Pa"
	        end if
        if (v.eq.4) then
           var = datfile->$U_varname$
           wgtFileName = wgtFileName_conserve
;           var = var  ;       convert to m/s
           var@long_name = "U-10m Speed"
           var@description = "Wind Speed of U10"
           var@units       = "m s^-1"
        end if
        if (v.eq.5) then
           var = datfile->$V_varname$
           wgtFileName = wgtFileName_conserve
;           var = var   ;       convert to m/s
           var@long_name = "V-10m Speed"
           var@description = "Wind Speed of V10"
           var@units       = "m s^-1"
        end if
        if (v.eq.6) then
           wgtFileName = wgtFileName_conserve
           var = datfile->$PCP_varname$
           var = (var*1000) / dt   ;       convert from m to mm/s
           var@long_name = "RAINRATE"
           var@description = "RAINRATE"
           var@units       = "mm s^-1"
        end if
        if (v.eq.7) then
           var = datfile->$DSWR_varname$
           var@_FillValue = 1.e+20 ; -9999;
           var=where(ismissing(var),0,var)
;           var = var / dt   ;  convert from (W m**-2 s) to (W m**-2)
           wgtFileName = wgtFileName_conserve
           var@description = "Downward Shortwave Radiation Flux"
           var@units       = "W m^-2"
        end if
        if (v.eq.8) then
           var = datfile->$DLWR_varname$
           var@_FillValue = 1.e+20 ; -9999;
           printMinMax(var, True)
           var=where(ismissing(var),300,var)
;           var = var / dt   ;  convert from (W m**-2 s) to (W m**-2)
           wgtFileName = wgtFileName_conserve
           var@description = "Downward Longwave Radiation Flux"
           var@units       = "W m^-2"
;   printMinMax(LWDOWN, True)
        end if
     
       printVarSummary(var)
     
       ;----------------------------------------------------------------------
       ; Define new array and perform regriddding
       ;----------------------------------------------------------------------
        ntimes = 1  ; for NLDAS, there is only one time step in each file
        v4 = new((/ntimes(0), dims(0), dims(1)/),"double")
       
       printVarSummary(v4)

       ;---Options to pass to ESMF_regrid--------------------;
     
        opt                = True
        opt@WgtFileName    = wgtFileName
        opt@CopyVarAtts    = True
        opt@CopyVarCoords  = False
     
       ;---Debug information
         opt@PrintTimings   = True
         opt@Debug          = True
       ;-----------------------------------------------------;
        exist = isfilepresent( wgtFileName )
        if ( .not.exist ) then
           print( " ... no wgtFile. Run ERA52WRFHydro_generate_weights.ncl first."+" "+wgtFileName )
           exit
        end if
     
        var2d = var
        v4 = ESMF_regrid_with_weights( var2d , wgtFileName, opt)

       ; printVarSummary(va)
       ; exit
     
       ;----------------------------------------------------------------------
       ; Export interpolated data to new forcing file...
       ;----------------------------------------------------------------------
       
       ;--- change dimension names so that ncks command works appropriately ---;
       v4!0 = "Time"
       v4!1 = "south_north"
       v4!2 = "west_east"
       v4@_FillValue = 1.0e+20;-1.e+36
       v4@missing_value = 1.0e+20;-1.e+36
       printVarSummary(v4)
       
       if (v.eq.1) then
              ncdf->T2D = v4
       else if (v.eq.2) then
              ncdf->Q2D = v4
       else if (v.eq.3) then
              ncdf->PSFC = v4
       else if (v.eq.4) then
              ncdf->U2D = v4
       else if (v.eq.5) then
              ncdf->V2D = v4
       else if (v.eq.6) then
              ncdf->RAINRATE = v4
       else if (v.eq.7) then
              ncdf->SWDOWN = v4
       else if (v.eq.8) then
              ncdf->LWDOWN = v4
       end if
       end if
       end if
       end if
       end if
       end if
       end if
       end if
       delete([/var,v4,var2d,wgtFileName/])
     
     end do   ; end do for variable loop
   
     dstFile = str_sub_str(ncfile, ".nc" , "")
     system( "mv "+ncfile+" "+dstFile)
   end do   ; end do for file loop


end

