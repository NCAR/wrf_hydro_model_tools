;----------------------------------------------------------------------
; cm2Hydro_forcing_ESMFregrid_1hr.ncl  
;
; Project : IOC
;
; Purpose : This is a ncl program to perform remapping of CMORPH data to hydro simulation
;           domain. 
;
; Usage   : ncl 'RUNNAME="BASELINE"' 'wrf_domain_name="d01"' \
;               'srcfilename="wrfout_d03*"' cm2Hydro_forcing_ESMFregrid_1hr.ncl  
;
;           RUNNAME     = name of wrf run.  This is used for the input path and the weight filename.
;           wrf_domain_name = domain name (d01, d02, d03) which is used to identify the weight file.
;           srcfilename = filename pattern of the souce wrfout files. Should have matching domain number.
; 
;For questions send email to: lpan@ucar.edu
;----------------------------------------------------------------------
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/ut_string.ncl"
;load "./ESMF_regridding.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

;----------------------------------------------------------------------
; Source, destination , and weight filenames for generating 
; ESMF_regridding weights
;----------------------------------------------------------------------
    wgtFileName_conserve =  wgtFileName_in

  if ( .not.isfilepresent( dstGridName ) ) then
     print( " ... source grid file not found : "+ dstGridName )
     exit
  end if

;----------------------------------------------------------------------
; read in source and destination grid netCDF files
;----------------------------------------------------------------------

;---  destination grid data
  dstfile     = addfile( dstGridName ,"r")
  dlon3d=dstfile->XLONG_M   ;(USER'S NEED TO CONFIRM THIS VARIABLE IS WHAT IS IN THEIR DATA FILE)
  dlat3d=dstfile->XLAT_M   ;(USER'S NEED TO CONFIRM THIS VARIABLE IS WHAT IS IN THEIR DATA FILE)

  dlon2d=dlon3d(0,:,:)
  dlat2d=dlat3d(0,:,:)

  dims=dimsizes(dlat2d)
  outFile = getenv("outFile")

;
;dg NEED TO EDIT INPUT DATA TIME INTERVAL HERE...
;
  dt=3600.0   ;forcing data timestep in seconds... (USER'S MUST ENTER/CONFIRM THIS IS SET TO DATA TIMESTEP (or INTERVAL))
  flag=0    ;WRF - flag for removing accum precip... (DO NOT CHANGE THIS)

;----------------------------------------------------------------------
; Open source data files to be regridded...
;----------------------------------------------------------------------
;
;dg NEED TO EDIT INPUT AND OUTPUT DIRECTORIES HERE...
;

  srcfilename = getenv ("srcFile")
  datfils = systemfunc ("/bin/ls -1 input_files/"+srcfilename)    ;list of file names
  num_datfils     = dimsizes(datfils)

   wgtFileName = wgtFileName_in

        opt                = True
        opt@WgtFileName    = wgtFileName
        opt@CopyVarAtts    = True
        opt@CopyVarCoords  = False

        opt@Debug          = True



  do ifil = 0,num_datfils-1,1   ; loop through datafiles one at a time

   
      datfile = addfile( datfils(ifil), "r")

      print( " ... Open input file : "+ datfils(ifil) )
  
;      if(.not. isfilevar(datfile,"VAR_209_6_9_P0_L102_GLL0")) then
;           exit()
;      end if 
  

     ;----------------------------------------------------------------------
     ; Temporary output
     ;----------------------------------------------------------------------
      if(isfilepresent(outFile) ) then
         system("rm -f "+outFile)
      end if

      ncdf= addfile(outFile,"c")
;      ncdf->lat = dlat2d   ;output lat
;      ncdf->lon = dlon2d   ;output lon

   
     ;----------------------------------------------------------------------
     ;  Processing...no further mods should be required...
     ;----------------------------------------------------------------------
     ;do v=6,6
      names  = getfilevarnames(datfile)
       do i = 0, dimsizes( names ) - 1
              if(names(i) .eq. "cmorph") then
	   precip_rate0 = datfile->cmorph
           precip_rate = ESMF_regrid_with_weights(precip_rate0 , wgtFileName, opt)
              end if
   
	if(names(i) .eq. "VAR_209_6_9_P0_L102_GLL0") then
	   temp = datfile->VAR_209_6_9_P0_L102_GLL0 
	   temp = where (temp < 0, temp@_FillValue, temp)
           precip_rate = ESMF_regrid_with_weights(temp , wgtFileName, opt)
	   precip_rate = where (precip_rate < 0, precip_rate@_FillValue, precip_rate)
	end if
	if(names(i) .eq. "VAR_209_6_2_P0_L102_GLL0") then
	   temp = datfile->VAR_209_6_2_P0_L102_GLL0 
	   temp = where (temp < 0, temp@_FillValue, temp)
           precip_rate = ESMF_regrid_with_weights(temp , wgtFileName, opt)
	   precip_rate = where (precip_rate < 0, precip_rate@_FillValue, precip_rate)
	end if
	end do
           precip_rate = precip_rate / 3600.0
           precip_rate@description = "RAINRATE"
           precip_rate@units       = "mm s^-1"
           ncdf->precip_rate = precip_rate

   
   end do   ; end do for file loop


end
