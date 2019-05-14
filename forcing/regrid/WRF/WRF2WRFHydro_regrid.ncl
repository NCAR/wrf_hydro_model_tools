;----------------------------------------------------------------------
;
;
; Remarks : (1) Assumes that wrfout files are hourly output. (-- important for
;               computing rainrate.
;           (2) ESMF regridding performed with "conserve" option for precipitation
;               and SWE. All other variables use bilinear option for remapping. 
;
;
; Usage   : ncl 'RUNNAME="BASELINE"' 'wrf_domain_name="d03"' \
;               'srcfilename="wrfout_d03*"' WRF2WRFHydro_regrid.ncl 
;
;           RUNNAME     = name of wrf run.  This is used for the input path and the weight filename.
;           wrf_domain_name = domain name (d01, d02, d03) which is used to identify the weight file.
;           srcfilename = filename pattern of the souce wrfout files. Should have matching domain number.
;                         e.g., "wrfout_d01_2007-09-01_00_00_00.nc", "wrfout_d01_2007*.nc"
;                               "wrfout_d01_2007-09-0[1-3].nc"
;
; Updated: May 14, 2019     K. FitzGerald 
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

dstGridName=""

dirm = ""

srcfilename=""

  ;---------------------------------------------------------------;
  ; Weight filenames for regridding                               ;
  ;---------------------------------------------------------------;
  wgtFileName_bilinear = "./WRF2WRFHydro_weight_bilinear.nc"

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
  
  flag=0    ;WRF - flag for removing accum precip... (DO NOT CHANGE THIS)

;----------------------------------------------------------------------
; Open source data files to be regridded...
;----------------------------------------------------------------------
  outdir  = "./output_files"      ; directory where output forcing data will be placed. set to dirm for overwriting the original file
  
  if(.not. isfilepresent(outdir)) then
     system("mkdir "+outdir)
  end if

  datfils = systemfunc ("ls "+dirm+srcfilename)    ;list of file names
  num_datfils     = dimsizes(datfils)

  num_datfils = 3	;To test only with one file

  do ifil = 0,num_datfils-1,1   ; loop through datafiles one at a time
      
      datfile = addfile( datfils(ifil), "r")
   
      print( " ... Open input file : "+ datfils(ifil) )


     ;names  = getfilevarnames(datfile) 
   
     ;-----------------------------------------------------------------
     ; Temporary output
     ;-----------------------------------------------------------------
      File = datfils(ifil)
      strs = str_split( File, "/")
      ;print(strs)
      sub_str = strs(7)     ; BE CAREFUL to pick the correct strig
      dtime_map = (/30/)
      outF = str_split_by_length(sub_str,dtime_map)

      ncfile=  outdir + "/" + outF(0)+".nc"

      if ( isfilepresent( ncfile ) ) then
         system ("/bin/rm "+ncfile)
      end if

      ncdf= addfile( ncfile,"c")
      print(ncdf)
      
      filedimdef( ncdf ,"Time",-1,True)
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
           wgtFileName = wgtFileName_bilinear 
        end if
        if (v.eq.7) then
           var = datfile->$PCP2_varname$
           wgtFileName = wgtFileName_bilinear 
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
              ;filevarattdef(ncdf,"T2",var2d) 
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
