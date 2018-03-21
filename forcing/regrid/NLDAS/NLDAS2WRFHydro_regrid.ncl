;----------------------------------------------------------------------
; Name    : NLDAS2WRFHydro_regrid.ncl
;
; Purpose : This is an NCL script that uses ESMF utilities to perform regridding of various 
;           data fields to a WRF-Hydro domain.
;
;           Note that before running this script you will need to run the 
;           NLDAS2WRFHydro_generate_weights.ncl script to generate the required weight
;           file(s) for your chosen regridding option(s). 
;
;           Important notes:
;           1) This script assumes that the source files are provided at an hourly interval.
;              This is true for the current generation of NLDAS forcing data and is an assumption made
;              to compute the rainrate variable in output files.          
;           2) This script is currently configured to use the bilinear interpolation option for all forcing 
;              fields.  Should the user desire to use a different interpolation option, the name for the
;              corresponding weight file should be added to user settings and the weight files for each 
;              variable adjusted appropriately.
;           3) NLDAS source files do not contain a "time" data field. This program will
;              parse time info from the filename and add it to the final netCDF file.
;           4) NLDAS A_PCP is hourly precipitation amount. No need for zero'ing it out
;              at the begining of the time period.
;           5) By default the domain number for the output filename is set to 1.  This can be changed in the 
;              user settings section of this script.
;
;
; Example Usage   : ncl 'srcFileName="NLDAS_FORA0125_H.*"' 'dstGridName="geo_em.d01.nc"' NLDAS2WRFHydro_regrid.ncl
;
;           srcFileName = filename pattern of the souce NLDAS files.
;                         e.g., "NLDAS_FORA0125_H.2013091300.grb", "NLDAS_FORA0125_H.2013091[2-5]00.grb" , ...
;           dstGridName = name of file that contains the destination (WRF-Hydro) grid
; 
; Kyoko Ikeda 23 December 2013
; Updated: Mar 15, 2018   K. FitzGerald
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
  ; Set the domain number to agree with the geogrid file and      ;
  ; the IGRID option in the hydro.namelist for WRF-Hydro          ;
  ;---------------------------------------------------------------;
  domain  = "DOMAIN1"

  ;---------------------------------------------------------------;
  ; Set input and output file directories.                        ;
  ;---------------------------------------------------------------;
  dirm    = "./input_files/"       ; directory where source forcing data resides
  outdir  = "./output_files/"      ; directory where regridded forcing data will be placed. set to dirm for overwriting the original file

  ;---------------------------------------------------------------;
  ; Set a variable to indicate the timestep of source data        ;
  ;---------------------------------------------------------------;
  dt=3600.0   ; time over which precipitation is accumulated in the source dataset in units of seconds (currently set for NLDAS2 forcing)

  ;---------------------------------------------------------------;
  ; Weight filenames for regridding                               ;
  ;---------------------------------------------------------------;
  ;wgtFileName_conserve = "./NLDAS2WRFHydro_weight_conserve.nc"
  wgtFileName_bilinear = "./NLDAS2WRFHydro_weight_bilinear.nc"

  ;---------------------------------------------------------------;
  ; Data field names from the source file to be regridded         ;
  ;---------------------------------------------------------------;
   P_varname = "PRES_110_SFC"
   T_varname = "TMP_110_HTGL"
   U_varname = "U_GRD_110_HTGL"
   V_varname = "V_GRD_110_HTGL"
   Q_varname = "SPF_H_110_HTGL"
   PCP_varname  = "A_PCP_110_SFC_acc1h"
   DSWR_varname = "DSWRF_110_SFC"
   DLWR_varname = "DLWRF_110_SFC"

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

  flag=0    ; flag for removing accum precip... (should be set to 0 for NLDAS2 forcing data)

;----------------------------------------------------------------------
; Open source data files to be regridded...
;----------------------------------------------------------------------
  system("mkdir "+outdir)

  datfils = systemfunc ("ls "+dirm+srcFileName)    ; list of file names
  num_datfils     = dimsizes(datfils)

  do ifil = 0,num_datfils-1,1   ; loop through datafiles one at a time
   
      datfile = addfile( datfils(ifil), "r")

      print( " ... Open input file : "+ datfils(ifil) )
   
     ;----------------------------------------------------------------------
     ; Parse time from filename : NLDAS_FORA0125_H.AYYYYMMDD.HH*
     ;----------------------------------------------------------------------
      strs = str_split( datfils(ifil), "." )
      sub_str = strs(1) + strs(2)
      dtime_map = (/1,4,2,2,2/)
      date_vec = str_split_by_length( sub_str, dtime_map)
      print( date_vec )

      date_str = date_vec(1)+date_vec(2)+date_vec(3)+date_vec(4)
  
      Times_str = date_vec(1)+"-"+date_vec(2)+"-"+date_vec(3)+"_"+date_vec(4)+":00:00"
      new_string = str_strip(Times_str)
      Times = stringtochar( new_string )
      Times!0 = "DateStrLen"

      valid_time = cd_inv_calendar(toint(date_vec(1)), toint(date_vec(2)), toint(date_vec(3)), toint(date_vec(4)), toint(0) ,toint(0) ,"seconds since 1970-01-01 00:00:00", 0)
      valid_time!0 = "Time"

     ;----------------------------------------------------------------------
     ; Open output file
     ;----------------------------------------------------------------------
      ncfile= outdir + date_str+".LDASIN_"+domain+".nc"
      if ( isfilepresent( ncfile ) ) then
         system ("/bin/rm "+ncfile)
      end if
      ncdf= addfile(ncfile,"c")
      filedimdef( ncdf ,"Time",-1,True)
      ncdf->lat = dlat2d   ;output lat
      ncdf->lon = dlon2d   ;output lon
      ncdf->Times = Times  ;output times
      ncdf->valid_time = valid_time
   
     ;----------------------------------------------------------------------
     ;  Processing...no further modifications should be required...
     ;----------------------------------------------------------------------
     do v=1,8
     
        if (v.eq.1) then
           var = datfile->$T_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.2) then
           var = datfile->$Q_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.3) then
           var = datfile->$U_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.4) then
           var = datfile->$V_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.5) then
           var = datfile->$P_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.6) then
           var = datfile->$PCP_varname$
           wgtFileName = wgtFileName_bilinear 
           var = var / dt ; convert from mm to mm/s
           var@long_name = "RAINRATE"
           var@description = "RAINRATE"
           var@units       = "mm s^-1"
        end if
        if (v.eq.7) then
           var = datfile->$DSWR_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.8) then
           var = datfile->$DLWR_varname$
           wgtFileName = wgtFileName_bilinear
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
           print( " ... no weight file. Run NLDAS2WRFHydro_generate_weights.ncl first to generate: "+" "+wgtFileName )
           exit
        end if
     
        var2d = var
        v4 = ESMF_regrid_with_weights( var2d , wgtFileName, opt)
     
       ;----------------------------------------------------------------------
       ; Export interpolated data to new forcing file...
       ;----------------------------------------------------------------------
       
       ;--- change dimension names so that ncks command works appropriately ---;
       v4!0 = "Time"
       v4!1 = "south_north"
       v4!2 = "west_east"
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
   end do   ; end do for file loop


end
