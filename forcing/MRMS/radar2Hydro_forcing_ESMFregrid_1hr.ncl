; --------------------------------------------------------------------------- ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Program Name: radar2Hydro_forcing_ESMFregrid_1hr.ncl                       ;
;                                                                             ;
;  National Water Model (NWM) WRF-hydro forcing engine is developed by        ;
;  National Center for Atmospheric Research (NCAR), under the sponsorship     ;
;  of National Water Center (NWC).                                            ;
;                                                                             ;
;   Team Members:                                                             ;
;     NCAR Staff: Linlin Pan, Wei Yu, and David Gochis                        ;
;      NWC/OWP Staff: Brian Cosgrove, Zhengtao Cui, Cham Pham, and James Taft ;
;                                                                             ;
;  This is a ncl program to perform  regridding.                              ;
;                                                                             ;
;  Input: radar file, weighting function, output file                         ;
;                                                                             ;
;  Output: regridded  file                                                    ;
;                                                                             ;
; For non-fatal errors output is witten to $DATA/logs                         ;
;                                                                             ;
; Author(s)/Contact(s): Linlin Pan, lpan@ucar.edu                             ;
; Origination                                                   Sept., 2015    ;
;                                                                             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
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
              if(names(i) .eq. "q3rad_gc_1h") then
	   precip_rate = datfile->q3rad_gc_1h
	   precip_rate1=precip_rate(0,0,::-1,:)
	   delete(precip_rate)
	   precip_rate=precip_rate1
	   delete(precip_rate1)
           precip_rate1 = ESMF_regrid_with_weights(precip_rate , wgtFileName, opt)
	    delete(precip_rate)
	    precip_rate=precip_rate1
	    delete(precip_rate1)
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
	if(names(i) .eq. "VAR_209_6_8_P0_L102_GLL0") then
	   temp = datfile->VAR_209_6_8_P0_L102_GLL0 
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
