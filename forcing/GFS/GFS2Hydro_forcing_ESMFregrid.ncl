; --------------------------------------------------------------------------- ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Program Name: GFS2Hydro_forcing_ESMFregrid.ncl                                ;
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
;  Input: gfs file, weighting function, output file                           ;
;                                                                             ;
;  Output: regridded  file                                                    ;
;                                                                             ;
; For non-fatal errors output is witten to $DATA/logs                         ;
;                                                                             ;
; Author(s)/Contact(s): Linlin Pan, lpan@ucar.edu                             ;
; Origination                                                   Sept., 2015    ;
;                                                                             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
  outdir  = "./output_files/"      ; directory where output forcing data will be placed. set to dirm for overwriting the original file
  if(.not. isfilepresent(outdir)) then
     system("mkdir "+outdir)
  end if

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
   
  
      names  = getfilevarnames(datfile) 

     ;----------------------------------------------------------------------
     ; Temporary output
     ;----------------------------------------------------------------------
      ncdf= addfile(outdir+"/"+outFile,"c")
      system("rm -f test.nc")
;      ncdf->lat = dlat2d   ;output lat
;      ncdf->lon = dlon2d   ;output lon

   
     ;----------------------------------------------------------------------
     ;  Processing...no further mods should be required...
     ;----------------------------------------------------------------------
     ;do v=6,6
   
;           print("lv_HTGL2 = "+ datfile->lv_HTGL2) 
           ; print("lv_HTGL5 = "+ datfile->lv_HTGL5) 
           ; print("lv_HTGL9 = "+ datfile->lv_HTGL9) 

           T2D = ESMF_regrid_with_weights(datfile->TMP_P0_L103_GLL0(0,:,:) , wgtFileName, opt)
           T2D@units="K"
           T2D@long_name="2-m Air Temperature"
           ncdf->T2D = T2D
	   delete(T2D)
           Q2D = ESMF_regrid_with_weights(datfile->SPFH_P0_L103_GLL0(0,:,:) , wgtFileName, opt)
           Q2D@units="kg kg-1"
           Q2D@long_name="2-m Specific humidity"
           ncdf->Q2D = Q2D
	   delete(Q2D)
;10 meter wind
           U2D = ESMF_regrid_with_weights(datfile->UGRD_P0_L103_GLL0(0,:,:) , wgtFileName, opt)
           U2D@units="m s-1"
           U2D@long_name="10-m U-component of wind"
           ncdf->U2D = U2D
	   delete(U2D)
           V2D = ESMF_regrid_with_weights(datfile->VGRD_P0_L103_GLL0(0,:,:) , wgtFileName, opt)
           V2D@units="m s-1"
           V2D@long_name="10-m V-component of wind"
           ncdf->V2D = V2D
	   delete(V2D)

           PSFC = ESMF_regrid_with_weights(datfile->PRES_P0_L1_GLL0 , wgtFileName, opt)
           PSFC@units="Pa"
           PSFC@long_name = "Surface Pressure"
           ncdf->PSFC = PSFC

           RAINRATE = PSFC
	   delete(PSFC)
           RAINRATE = 0.0
           RAINRATE@description = "RAINRATE"
           RAINRATE@long_name = "Surface Precipitation Rate"
           RAINRATE@units       = "mm s^-1"
           do i = 0, dimsizes( names ) - 1
              if(names(i) .eq. "PRATE_P8_L1_GLL0_avg") then
                  RAINRATE = ESMF_regrid_with_weights(datfile->PRATE_P8_L1_GLL0_avg, wgtFileName, opt) 
              end if
              if(names(i) .eq. "PRATE_P8_L1_GLL0_avg6h") then
                  RAINRATE = ESMF_regrid_with_weights(datfile->PRATE_P8_L1_GLL0_avg6h, wgtFileName, opt) 
              end if
              if(names(i) .eq. "PRATE_P8_L1_GLL0_avg3h") then
                  RAINRATE = ESMF_regrid_with_weights(datfile->PRATE_P8_L1_GLL0_avg3h, wgtFileName, opt) 
              end if
              if(names(i) .eq. "DLWRF_P8_L1_GLL0_avg") then
                  LWDOWN = ESMF_regrid_with_weights(datfile->DLWRF_P8_L1_GLL0_avg, wgtFileName, opt) 
                  LWDOWN@units="W m-2"
                  LWDOWN@long_name="Surface downward long-wave radiation flux"
                  ncdf->LWDOWN = LWDOWN
	             delete(LWDOWN)
              end if
              if(names(i) .eq. "DLWRF_P8_L1_GLL0_avg3h") then
                  LWDOWN = ESMF_regrid_with_weights(datfile->DLWRF_P8_L1_GLL0_avg3h, wgtFileName, opt) 
                  LWDOWN@units="W m-2"
                  LWDOWN@long_name="Surface downward long-wave radiation flux"
                  ncdf->LWDOWN = LWDOWN
	             delete(LWDOWN)
              end if
              if(names(i) .eq. "DLWRF_P8_L1_GLL0_avg6h") then
                  LWDOWN = ESMF_regrid_with_weights(datfile->DLWRF_P8_L1_GLL0_avg6h, wgtFileName, opt) 
                  LWDOWN@units="W m-2"
                  LWDOWN@long_name="Surface downward long-wave radiation flux"
                  ncdf->LWDOWN = LWDOWN
	             delete(LWDOWN)
              end if
              if(names(i) .eq. "DSWRF_P8_L1_GLL0_avg") then
                  SWDOWN = ESMF_regrid_with_weights(datfile->DSWRF_P8_L1_GLL0_avg , wgtFileName, opt) 
                  SWDOWN@units="W m-2"
                  SWDOWN@long_name="Surface downward short-wave radiation flux"
                  ncdf->SWDOWN = SWDOWN
	             delete(SWDOWN)
              end if
              if(names(i) .eq. "DSWRF_P8_L1_GLL0_avg3h") then
                  SWDOWN = ESMF_regrid_with_weights(datfile->DSWRF_P8_L1_GLL0_avg3h , wgtFileName, opt) 
                  SWDOWN@units="W m-2"
                  SWDOWN@long_name="Surface downward short-wave radiation flux"
                  ncdf->SWDOWN = SWDOWN
	             delete(SWDOWN)
              end if
              if(names(i) .eq. "DSWRF_P8_L1_GLL0_avg6h") then
                  SWDOWN = ESMF_regrid_with_weights(datfile->DSWRF_P8_L1_GLL0_avg6h , wgtFileName, opt) 
                  SWDOWN@units="W m-2"
                  SWDOWN@long_name="Surface downward short-wave radiation flux"
                  ncdf->SWDOWN = SWDOWN
	             delete(SWDOWN)
              end if
           end do

           ncdf->RAINRATE = RAINRATE

	             delete(RAINRATE)

;           WEASD = ESMF_regrid_with_weights(datfile->WEASD_P0_L1_GLL0, wgtFileName, opt) 
;           ncdf->WEASD = WEASD
;         delete(WEASD)
     
   
   end do   ; end do for file loop


end
