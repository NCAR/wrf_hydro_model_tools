;----------------------------------------------------------------------
;
; Name    : WRF2WRFHydro_regrid.ncl
;
; Purpose : This is an NCL script that uses ESMF utilities to perform regridding of various 
;           data fields to a WRF-Hydro domain.
;
;           Note that before running this script you will need to run the 
;           WRF2WRFHydro_generate_weights.ncl script to generate the required weight
;           file(s) for your chosen regridding option(s). 
;
;           Important notes:
;           1) This script is currently configured to use the bilinear interpolation option for all forcing 
;              fields except precipitation which uses conservative regridding.  Should the user desire to use
;              different interpolation options, the name for the
;              corresponding weight file should be added to user settings and the weight files for each 
;              variable adjusted appropriately.
;
; Example Usage : ncl 'srcFileName="wrfout*"' 'dstGridName="geo_em.d02.nc"' WRF2WRFHydro_regrid.ncl
;
;           srcFileName = filename pattern of the source files
;                         e.g. "wrfout_d01*"
;           dstGridName = name of file that contains the destination (WRF-Hydro) grid
;
;
; Updated: June 24, 2020     K. FitzGerald 
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
  ; Weight filenames for regridding                               ;
  ;---------------------------------------------------------------;
  wgtFileName_bilinear = "./WRF2WRFHydro_weight_bilinear.nc"
  wgtFileName_conserve = "./WRF2WRFHydro_weight_bilinear.nc"

  ;---------------------------------------------------------------;
  ; Data field names from the source file to be regridded         ;
  ;---------------------------------------------------------------;
   P_varname = "PSFC"
   T_varname = "T2"
   U_varname = "U10"
   V_varname = "V10"
   Q_varname = "Q2"
   PCP_varname  = "RAINC"
   PCP2_varname  = "RAINNC"
   DSWR_varname = "SWDOWN"
   DLWR_varname = "GLW"
   VEGFRA_varname = "VEGFRA"
   LAI_varname = "LAI"
  
;----------------------------------------------------------------------
; read in source and destination grid netCDF files
;----------------------------------------------------------------------

;---  destination grid data
  dstfile     = addfile( dstGridName ,"r")
  dlon2d=dstfile->XLONG_M(0,:,:)
  dlat2d=dstfile->XLAT_M(0,:,:)
  dims=dimsizes(dlat2d)
  
;----------------------------------------------------------------------
; Open source data files to be regridded...
;----------------------------------------------------------------------
  outdir  = "./output_files"      ; directory where output forcing data will be placed. set to dirm for overwriting the original file
  
  if(.not. isfilepresent(outdir)) then
     system("mkdir "+outdir)
  end if

  datfils = systemfunc ("ls input_files/"+srcFileName)    ;list of file names
  num_datfils     = dimsizes(datfils)

  do ifil = 0,num_datfils-1,1   ; loop through datafiles one at a time
      
      datfile = addfile( datfils(ifil), "r")
      sTime=datfile->Times
   
      print( " ... Open input file : "+ datfils(ifil) )


     ;-----------------------------------------------------------------
     ; Temporary output
     ;-----------------------------------------------------------------
      File = datfils(ifil)
      strs = str_split( File, "/")
      sub_str = strs(dimsizes(strs)-1)     ; BE CAREFUL to pick the correct strig
      dtime_map = (/30/)
      outF = str_split_by_length(sub_str,dtime_map)

      ncfile=  outdir + "/" + outF(0)+".nc"

      if ( isfilepresent( ncfile ) ) then
         system ("/bin/rm "+ncfile)
      end if

      ncdf= addfile( ncfile,"c")
      print(ncdf)
      
      filedimdef( ncdf ,"Time",-1,True)
      ncdf->Time = sTime   ;output time
      ncdf->lat = dlat2d   ;output lat
      ncdf->lon = dlon2d   ;output lon
   
     ;-----------------------------------------------------------------
     ;  Processing...no further mods should be required...
     ;-----------------------------------------------------------------
     do v=1,11
     
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
           wgtFileName = wgtFileName_conserve 
        end if
        if (v.eq.7) then
           var = datfile->$PCP2_varname$
           wgtFileName = wgtFileName_conserve 
        end if
        if (v.eq.8) then
           var = datfile->$DSWR_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.9) then
           var = datfile->$DLWR_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.10) then
           var = datfile->$VEGFRA_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.11) then
           var = datfile->$LAI_varname$
           wgtFileName = wgtFileName_bilinear
        end if
     
       printVarSummary(var)      

       ;---------------------------------------------------------------
       ; Define new array and perform regriddding
       ;---------------------------------------------------------------
        ntimes = 1  ; for WRF, there is only one time step in each file
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
           print( " ... no weight file. Run WRF2WRFHydro_generate_weights.ncl first to generate: "+" "+wgtFileName )
           exit
        end if
     
        var2d = var
        v4 = ESMF_regrid_with_weights( var2d , wgtFileName, opt)
       ;---------------------------------------------------------------
       ; Export interpolated data to new forcing file...
       ;---------------------------------------------------------------

       ;--- change dimension names so that ncks command works appropriately ---;
       v4!0 = "Time"
       v4!1 = "south_north"
       v4!2 = "west_east"
       printVarSummary(v4)
       
       if (v.eq.1) then
              ncdf->T2 = v4
       else if (v.eq.2) then
              ncdf->Q2 = v4
       else if (v.eq.3) then
              ncdf->U10 = v4
       else if (v.eq.4) then
              ncdf->V10 = v4
       else if (v.eq.5) then
              ncdf->PSFC = v4
       else if (v.eq.6) then
              ncdf->RAINC = v4
       else if (v.eq.7) then
              ncdf->RAINNC = v4
       else if (v.eq.8) then
              ncdf->SWDOWN = v4
       else if (v.eq.9) then
              ncdf->GLW = v4
       else if (v.eq.10) then
              ncdf->VEGFRA = v4
       else if (v.eq.11) then
              ncdf->LAI = v4

       end if
       end if
       end if
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
