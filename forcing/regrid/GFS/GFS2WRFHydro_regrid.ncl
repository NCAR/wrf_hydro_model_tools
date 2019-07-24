;----------------------------------------------------------------------
; Name    : GFS2WRFHydro_regrid.ncl
;
; Purpose : This is an NCL script that uses ESMF utilities to perform regridding of various  
;           data fields to a WRF-Hydro domain.
;
;           Note that before running this script you will need to run the 
;           GFS2WRFHydro_generate_weights.ncl script to generate the required weight
;           file(s) for your chosen regridding option(s). 
;
;           Important notes:
;           1) This script is currently configured to use the bilinear interpolation option for all forcing 
;              fields.  Should the user desire to use a different interpolation option, the name for the
;              corresponding weight file should be added to user settings and the weight files for each 
;              variable adjusted appropriately.
;           2) Given that GFS is a forecast, were we to generate output files from this script with the 
;              proper naming conventions for WRF-Hydro there would potentially be more than one file with
;              the same name.  Therefore we leave the step of renaming output files to meet the WRF-Hydro
;              input filename convention to the user.  
;
;
; Example Usage   : ncl 'srcFileName="gfs.*.pgrb2.0p25.*"' 'dstGridName="geo_em.d01.nc"' GFS2WRFHydro_regrid.ncl
;
;           srcFileName = filename pattern of the souce GFS files.
;                         e.g., "gfs.t00z.pgrb2.0p25.f001", "gfs.*.pgrb2.0p25.*" , ...
;           dstGridName = name of file that contains the destination (WRF-Hydro) grid
; 
; NCAR WRF-Hydro Team
; Updated: Mar 20, 2018   K. FitzGerald
; Updated: Mar 11, 2019   Yongxin Zhang
; Updated: Jul 24, 2019   K. FitzGerald
;
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
  outdir  = "./"      ; directory where regridded forcing data will be placed. set to dirm for overwriting the original file

  ;---------------------------------------------------------------;
  ; Weight filenames for regridding                               ;
  ;---------------------------------------------------------------;
  ;wgtFileName_conserve = "./GFS2WRFHydro_weight_conserve.nc"
  wgtFileName_bilinear = "./GFS2WRFHydro_weight_bilinear.nc"

  ;---------------------------------------------------------------;
  ; Data field names from the source file to be regridded         ;
  ;---------------------------------------------------------------;
   P_varname = "PRES_P0_L1_GLL0"
   T_varname = "TMP_P0_L103_GLL0"
   U_varname = "UGRD_P0_L103_GLL0"
   V_varname = "VGRD_P0_L103_GLL0"
   Q_varname = "SPFH_P0_L103_GLL0"
   PCP_varname  = "PRATE_P8_L1_GLL0_avg" ; or similar 
   DSWR_varname = "DSWRF_P8_L1_GLL0_avg" ; or similar
   DLWR_varname = "DLWRF_P8_L1_GLL0_avg" ; or similar

;----------------------------------------------------------------------
; read in source and destination files
;----------------------------------------------------------------------

  if ( .not.isfilepresent( dstGridName ) ) then
     print( " ... source grid file not found : "+ dstGridName )
     exit
  end if

;---  destination grid data
  dstfile     = addfile( dstGridName ,"r")
  dlon2d=dstfile->XLONG_M(0,:,:)
  dlat2d=dstfile->XLAT_M(0,:,:)
  dims=dimsizes(dlat2d)

  flag=0    ; flag for removing accum precip... 

;----------------------------------------------------------------------
; Open source data files to be regridded...
;----------------------------------------------------------------------

  datfils = systemfunc ("ls "+dirm+srcFileName)    ; list of file names
  num_datfils     = dimsizes(datfils)

  do ifil = 0,num_datfils-1,1   ; loop through datafiles one at a time
      
      datfile = addfile( datfils(ifil) + ".grb2", "r")

      print( " ... Open input file : "+ datfils(ifil) )

      vnames = getfilevarnames(datfile)
   
     ;----------------------------------------------------------------------
     ; Parse time from the attributes of any of the variables 
     ; based on the initial time plus the forecast time.
     ;----------------------------------------------------------------------
      var_swap = datfile->$T_varname$
      ymdt_swap1 = var_swap@initial_time
      ymdt_swap2 = str_split(ymdt_swap1," ")
      ymdt_swap3 = str_split(ymdt_swap2(0),"/")
      yyyy_int  = tointeger(ymdt_swap3(2))
      mm_int    = tointeger(ymdt_swap3(0))
      dd_int    = tointeger(ymdt_swap3(1)) 

      ymdt_swap4   = str_split_by_length(ymdt_swap2(1),(/1,2,1,2/))
      hh_initial   = tointeger(ymdt_swap4(1))
      hh_forecast  = tointeger(var_swap@forecast_time)
      hh_integer   = hh_initial + hh_forecast

      hh = sprinti("%0.2i", mod(hh_integer,24))

      hh_int_days  = hh_integer/24      

      doy_initial  = day_of_year(yyyy_int,mm_int,dd_int)
      doy_forecast = doy_initial + hh_int_days

      if(isleapyear(yyyy_int)) then
       max_days = 366 
      else
       max_days = 365
      end if

      if(doy_forecast .gt. max_days) then
       yyyy_int = yyyy_int + 1
       doy_forecast = doy_forecast - max_days
      end if

      mmdd_int    = monthday(yyyy_int,doy_forecast)
      mmdd        = sprinti("%0.4i",mmdd_int)
      mmdd_split  = str_split_by_length(mmdd,(/2,2/))

      yyyy = tostring(yyyy_int)
      mm   = mmdd_split(0)
      dd   = mmdd_split(1)
     
      yyyymmddhh = yyyy+mm+dd+hh
      delete([/var_swap,ymdt_swap1,ymdt_swap2,ymdt_swap3,ymdt_swap4/])
      delete([/mmdd_split,mmdd_int,mmdd,doy_initial,doy_forecast,max_days/])
      delete([/yyyy_int,mm_int,dd_int,hh_int_days/])
      delete([/hh_initial,hh_forecast,hh_integer/])
     ;----------------------------------------------------------------------
     ; Open output file
     ;----------------------------------------------------------------------
      ncfile = yyyymmddhh+".LDASIN_DOMAIN1.nc"
      if ( isfilepresent( ncfile ) ) then
         system ("/bin/rm "+ncfile)
      end if
      ncdf= addfile(ncfile,"c")
      ncdf->lat = dlat2d   ;output lat
      ncdf->lon = dlon2d   ;output lon
   
     ;----------------------------------------------------------------------
     ;  Processing...no further modifications should be required...
     ;----------------------------------------------------------------------
     do v=1,8
     
        if (v.eq.1) then
           var = datfile->$T_varname$(0,:,:)
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.2) then
           var = datfile->$Q_varname$(0,:,:)
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.3) then
           var = datfile->$U_varname$(0,:,:)
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.4) then
           var = datfile->$V_varname$(0,:,:)
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.5) then
           var = datfile->$P_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.6) then
           PCP_fullvarname = str_match(vnames, PCP_varname)
           var = datfile->$PCP_fullvarname$
           wgtFileName = wgtFileName_bilinear 
           var@long_name = "RAINRATE"
           var@description = "RAINRATE"
           var@units       = "mm s^-1"
        end if
        if (v.eq.7) then
           DSWR_fullvarname = str_match(vnames, DSWR_varname)
           var = datfile->$DSWR_fullvarname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.8) then
           DLWR_fullvarname = str_match(vnames, DLWR_varname)
           var = datfile->$DLWR_fullvarname$
           wgtFileName = wgtFileName_bilinear
        end if
     
       printVarSummary(var)
     
       ;----------------------------------------------------------------------
       ; Define new array and perform regriddding
       ;----------------------------------------------------------------------
        v4 = new((/dims(0), dims(1)/),"double")
       
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
           print( " ... no weight file. Run GFS2WRFHydro_generate_weights.ncl first to generate: "+" "+wgtFileName )
           exit
        end if
     
        var2d = var
        v4 = ESMF_regrid_with_weights( var2d , wgtFileName, opt)
     
       ;----------------------------------------------------------------------
       ; Export interpolated data to new forcing file...
       ;----------------------------------------------------------------------
       
       v4!0 = "south_north"
       v4!1 = "west_east"
       printVarSummary(v4)
       
       if (v.eq.1) then
              ncdf->T2D = v4
       else if (v.eq.2) then
              ncdf->Q2D = v4
       else if (v.eq.3) then
              ncdf->U2D = v4
       else if (v.eq.4) then
              ncdf->V2D = v4
       else if (v.eq.5) then
              ncdf->PSFC = v4
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
     
     delete([/vnames/])
       
   end do   ; end do for file loop

end
