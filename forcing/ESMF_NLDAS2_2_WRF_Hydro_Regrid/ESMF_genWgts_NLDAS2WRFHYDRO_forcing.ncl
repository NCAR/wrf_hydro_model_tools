;----------------------------------------------------------------------
; NCAR Command Language Version 6.1.2
;
; ESMF_genWgts_NLDAS2WRFHYDRO_forcing.ncl
;
; Project :
;
; Purpose :
;           This is an NCL/ESMF file for generating src and dst SCRIP files
;           and weight file for regridding from a rectilinear NLDAS grid to a WRF
;           HYDRO model domain, which is also in curvilinear coordinates
;
;           1) the first rectilinear_to_SCRIP to convert original source rectilinear
;              grid to a SCRIP convention file.
;           2) the second curvilinear_to_SCRIP to convert destination lat/lon grid to a
;              SCRIP convention file.
;           3) ESMF_regrid_gen_weights to generate a weight file using a remapping
;              option specified in the command line.
;
;           The rectilinear grid definition is assumed to be in srsGridName file.
;           Needs 1D lat/long fields for rectilinear_to_SCRIP
;
;           Destination domain filename (dstGRIDName) is hardwired in the program.
; 
; Usage    : ncl 'interp_opt="conserve"' 'srcGridName="NLDAS_FORA0125_H.2013091200.nc"' 'dstGridName="geo_em.d01.nc.4mile_1km.nc"' ESMF_genWgts_NLDAS2WRFHYDRO_forcing.ncl
;
;            interp_opt = conserve / bilinear / patch
;            srcGridName = filename that contains source grid
;
; Kyoko Ikeda 23 Dec. 2013
; Updated: Jul 9, 2014    D. Gochis
;            
;----------------------------------------------------------------------
;
; For more information about ESMF:
;
;        http://www.earthsystemmodeling.org/
;
; This script uses built-in functions that are only available in 
; NCL V6.1.0-beta and later.
;
; For more information on ESMF_regrid, see: 
;    http://www.ncl.ucar.edu/Document/Functions/ESMF/ESMF_regrid.shtml
;----------------------------------------------------------------------
;----------------------------------------------------------------------
;----------------------------------------------------------------------
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

;----------------------------------------------------------------------
; User settings
;----------------------------------------------------------------------

  ;---------------------------------------------------------------;
  ; Set source and destination grid filenames.                    ;
  ; Defind weight filename.                                       ;
  ;---------------------------------------------------------------;
    wgtFileName = "./NLDAS_to_WRFHYDRO_weight_"+interp_opt+".nc"

  if ( .not.isfilepresent( srcGridName ) ) then
     print( " ... source grid file not found : "+ srcGridName )
     exit
  end if

  if ( .not.isfilepresent( dstGridName ) ) then
     print( " ... destination grid file not found : "+ dstGridName )
     exit
  else
     ; dstGridName = "geo_em.d01.nc.4mile_1km.nc"
  end if

  ;---------------------------------------------------------------;
  ; Field names for lat and lon coordinates in the source file.   ;
  ;---------------------------------------------------------------;
  LatName = "lat_110"
  LonName = "lon_110"

;----------------------------------------------------------------------
; Convert source grid to a SCRIP convention file.
;----------------------------------------------------------------------
    src_file = addfile(srcGridName,"r")
    vNames   = getfilevarnames( src_file )

    if ( isfilevar( src_file, LatName ) .and. isfilevar( src_file, LonName ) ) then
       src_lat = src_file->$LatName$
       src_lon = src_file->$LonName$
    else
       print( " ... no such lat/lon fieldnames" )
       exit
    end if

    if ( isfilevar( src_file, "TMP_110_HTGL" ) ) then
       test_mask = src_file->TMP_110_HTGL
    else
       print( " ... no such data field " )
       exit
    end if

    Opt                = True
    Opt@Mask2D         = where(.not.ismissing(test_mask),1,0)
    Opt@SrcRegional    = True
    Opt@ForceOverwrite = True
    Opt@PrintTimings   = True
    Opt@Title          = "NLDAS"

    src_SCRIP_filename     = "src_NLDAS2WRFHYDRO_"+interp_opt+".nc"
    rectilinear_to_SCRIP( src_SCRIP_filename, src_lat, src_lon, Opt)
;---Clean up
    delete(Opt)

;----------------------------------------------------------------------
; Convert destination grid to a SCRIP convention file.
;----------------------------------------------------------------------
    dst_file = addfile(dstGridName,"r")

    if ( isfilevar( dst_file, "XLAT" ) .and. .not. isfilevar( dst_file, "XLAT_M") ) then
       dst_lat = dst_file->XLAT(0,:,:)
       dst_lon = dst_file->XLONG(0,:,:)
    end if

    if ( isfilevar( dst_file, "XLAT_M" ) .and. .not. isfilevar( dst_file, "XLAT" ) ) then
       dst_lat = dst_file->XLAT_M(0,:,:)
       dst_lon = dst_file->XLONG_M(0,:,:)
    end if

    Opt                = True
    Opt@DstRegional    = True
    Opt@ForceOverwrite = True
    Opt@PrintTimings   = True
    Opt@Title          = dstGridName

    dst_SCRIP_filename     = "dst_NLDAS2WRFHYDRO_"+interp_opt+".nc"
    curvilinear_to_SCRIP( dst_SCRIP_filename, dst_lat, dst_lon,Opt)

;---Clean up
    delete(Opt)

;----------------------------------------------------------------------
; Generate the weights that take you from the source grid to 
; destination degree grid.
;----------------------------------------------------------------------
    Opt                      = True
    Opt@InterpMethod         = interp_opt
    Opt@DstRegional          = True
    Opt@ForceOverwrite       = True
    Opt@PrintTimings         = True
    Opt@Debug                = True

    ESMF_regrid_gen_weights( src_SCRIP_filename, dst_SCRIP_filename, wgtFileName, Opt)

    delete(Opt)

;----------------------------------------------------------------------
;----------------------------------------------------------------------
end