; --------------------------------------------------------------------------- ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Program Name: HRRR2Hydro_forcing_ESMFregrid.ncl                                ;
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
;  Input: hrrr file, weighting function, output file                           ;
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


; begin added by Wei Yu
      if(.not. isfilevar(datfile,"TMP_P0_L103_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"SPFH_P0_L103_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"UGRD_P0_L103_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"VGRD_P0_L103_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"PRES_P0_L1_GLC0")) then
           exit()
      end if
      if(.not. isfilevar(datfile,"DSWRF_P0_L1_GLC0")) then
           exit()
      end if
; end added by Wei Yu   


     names  = getfilevarnames(datfile) 
   
     ;----------------------------------------------------------------------
     ; Temporary output
     ;----------------------------------------------------------------------
      ncdf= addfile(outdir+"/"+outFile,"c")
;      ncdf->lat = dlat2d   ;output lat
;      ncdf->lon = dlon2d   ;output lon
          globalAtt = True
           globalAtt@missing_value = -1.e+33

           fileattdef( ncdf, globalAtt )


   
     ;----------------------------------------------------------------------
     ;  Processing...no further mods should be required...
     ;----------------------------------------------------------------------
     ;do v=6,6
    
          x = datfile->TMP_P0_L103_GLC0
          delete_VarAtts(x, -1) 
           T2D0 = ESMF_regrid_with_weights(x , wgtFileName, opt)
           dd = dimsizes(T2D0)
           print("dd="+dd)
           dimlat = dd(0)
           dimlon = dd(1)
           dimNames = (/"time", "south_north", "west_east"/)
           dimSizes = (/ -1   ,  dimlat,  dimlon /)
           dimUnlim = (/ True , False, False/)
           filedimdef(ncdf,dimNames,dimSizes,dimUnlim)

;          time=new((/1/),integer)
;          time=stringtointeger(time)
	   time=1
           time!0="time"
           time@long_name="valid output time"
           filevardef(ncdf, "time"   ,typeof(time) ,getvardims(time))
           filevarattdef(ncdf,"time"   ,time)
           ncdf->time=(/time/)

           T2D = new((/1,dimlat,dimlon/),float)
           Q2D = new((/1,dimlat,dimlon/),float)
           PSFC = new((/1,dimlat,dimlon/),float)
           LWDOWN = new((/1,dimlat,dimlon/),float)
           SWDOWN = new((/1,dimlat,dimlon/),float)
           RAINRATE = new((/1,dimlat,dimlon/),float)
           U2D = new((/1,dimlat,dimlon/),float)
           V2D = new((/1,dimlat,dimlon/),float)
           T2D(0,:,:)=T2D0
           delete(T2D0)


           T2D@missing_value=-1.e+33
           T2D@_FillValue=9.96921e+36
           T2D@units="K"
           T2D@long_name="2-m Air Temperature"
           T2D!0="time"
           T2D!1="south_north"
           T2D!2="west_east"
           filevardef(ncdf, "T2D"   ,typeof(T2D) ,getvardims(T2D))
           filevarattdef(ncdf,"T2D"   ,T2D)
           ncdf->T2D = (/T2D/)
           delete(T2D)

           Q2D = ESMF_regrid_with_weights(datfile->SPFH_P0_L103_GLC0 , wgtFileName, opt)
           Q2D@missing_value=-1.e+33
           Q2D@_FillValue=9.96921e+36
           Q2D@units="kg kg-1"
           Q2D@long_name="2-m Specific humidity"
           Q2D!0="time"
           Q2D!1="south_north"
           Q2D!2="west_east"
           filevardef(ncdf, "Q2D"   ,typeof(Q2D) ,getvardims(Q2D))
           filevarattdef(ncdf,"Q2D"   ,Q2D)
           ncdf->Q2D = (/Q2D/)

;10 meter wind
           print("**************  start regrid U2D ************** ")
           U2D = ESMF_regrid_with_weights(datfile->UGRD_P0_L103_GLC0(0,:,:) , wgtFileName, opt)
           U2D@missing_value=-1.e+33
           U2D@_FillValue=9.96921e+36
           U2D@units="m s-1"
           U2D@long_name="10-m U-component of wind"
           U2D!0="time"
           U2D!1="south_north"
           U2D!2="west_east"
           filevardef(ncdf, "U2D"   ,typeof(U2D) ,getvardims(U2D))
           filevarattdef(ncdf,"U2D"   ,U2D)
           ncdf->U2D = (/U2D/)
           delete(U2D)
           
           print("**************  start regrid V2D ************** ")
           V2D = ESMF_regrid_with_weights(datfile->VGRD_P0_L103_GLC0(0,:,:) , wgtFileName, opt)
           V2D@missing_value=-1.e+33
           V2D@_FillValue=9.96921e+36
           V2D@units="m s-1"
           V2D@long_name="10-m V-component of wind"
           V2D!0="time"
           V2D!1="south_north"
           V2D!2="west_east"
           filevardef(ncdf, "V2D"   ,typeof(V2D) ,getvardims(V2D))
           filevarattdef(ncdf,"V2D"   ,V2D)
           ncdf->V2D = (/V2D/)
           delete(V2D)


           print("**************  start regrid PSFC ************** ")
           PSFC = ESMF_regrid_with_weights(datfile->PRES_P0_L1_GLC0 , wgtFileName, opt)
           PSFC@missing_value=-1.e+33
           PSFC@_FillValue=9.96921e+36
           PSFC@units="Pa"
           PSFC@long_name = "Surface Pressure"
           PSFC!0="time"
           PSFC!1="south_north"
           PSFC!2="west_east"
           filevardef(ncdf, "PSFC"   ,typeof(PSFC) ,getvardims(PSFC))
           filevarattdef(ncdf,"PSFC"   ,PSFC)
           ncdf->PSFC = (/PSFC/)
           RAINRATE = 0.0
           RAINRATE@missing_value=-1.e+33
           RAINRATE@_FillValue=9.96921e+36
           RAINRATE@description = "RAINRATE"
           RAINRATE@long_name = "Surface Precipitation Rate"
           RAINRATE@units       = "mm s^-1"
           RAINRATE!0="time"
           RAINRATE!1="south_north"
           RAINRATE!2="west_east"
           filevardef(ncdf, "RAINRATE"   ,typeof(RAINRATE) ,getvardims(RAINRATE))
           filevarattdef(ncdf,"RAINRATE"   ,RAINRATE)

           do i = 0, dimsizes( names ) - 1
              if(names(i) .eq. "APCP_P8_L1_GLC0_acc") then
                  ytmp     = ESMF_regrid_with_weights(datfile->APCP_P8_L1_GLC0_acc , wgtFileName, opt) 
                  RAINRATE(0,:,:) = (/ytmp/)
                  delete(ytmp)
                  RAINRATE = RAINRATE/3600
                  RAINRATE@description = "RAINRATE"
                  RAINRATE@units       = "mm s^-1"
                  ncdf->RAINRATE = (/RAINRATE/)
              end if
              if(names(i) .eq. "APCP_P8_L1_GLC0_acc1h") then
                  ytmp     = ESMF_regrid_with_weights(datfile->APCP_P8_L1_GLC0_acc1h , wgtFileName, opt) 
                  RAINRATE(0,:,:) = (/ytmp/)
                  delete(ytmp)
                  RAINRATE = RAINRATE/3600
                  RAINRATE@description = "RAINRATE"
                  RAINRATE@units       = "mm s^-1"
                  ncdf->RAINRATE = (/RAINRATE/)
              end if
           end do

           SWDOWN = ESMF_regrid_with_weights(datfile->DSWRF_P0_L1_GLC0 , wgtFileName, opt) 
           SWDOWN@missing_value=-1.e+33
           SWDOWN@_FillValue=9.96921e+36
           SWDOWN@units="W m-2"
           SWDOWN@long_name="Surface downward short-wave radiation flux"
           SWDOWN!0="time"
           SWDOWN!1="south_north"
           SWDOWN!2="west_east"
           filevardef(ncdf, "SWDOWN"   ,typeof(SWDOWN) ,getvardims(SWDOWN))
           filevarattdef(ncdf,"SWDOWN"   ,SWDOWN)
           ncdf->SWDOWN = (/SWDOWN/)
           delete(SWDOWN)

;LWDOWN need to be mofified later
           LWDOWN = ESMF_regrid_with_weights(datfile->ULWRF_P0_L8_GLC0, wgtFileName, opt) 
           LWDOWN@missing_value=-1.e+33
           LWDOWN@_FillValue=9.96921e+36
           LWDOWN@units="W m-2"
           LWDOWN@long_name="Surface downward long-wave radiation flux"
           LWDOWN!0="time"
           LWDOWN!1="south_north"
           LWDOWN!2="west_east"
           filevardef(ncdf, "LWDOWN"   ,typeof(LWDOWN) ,getvardims(LWDOWN))
           filevarattdef(ncdf,"LWDOWN"   ,LWDOWN)
           ncdf->LWDOWN = (/LWDOWN/)
           delete(LWDOWN)

;           WEASD = ESMF_regrid_with_weights(datfile->WEASD_P0_L1_GLC0, wgtFileName, opt) 
;           ncdf->WEASD = WEASD
     
   
   end do   ; end do for file loop


end
