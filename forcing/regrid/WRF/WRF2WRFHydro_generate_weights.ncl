;----------------------------------------------------------------------
; 
; Name    : WRF2WRFHydro_generate_weights.ncl
;
; Purpose : This is an NCL script that uses EMSF utililites to generate src and dst SCRIP files
;           and a weight file for regridding from a curvilinear WRF model grid to a
;           WRF-Hydro model domain, a curvilinear grid specified in a geo_em.d0x.nc file. 
;
;           Steps:
;           1) Use curvilinear_to_SCRIP to create a SCRIP (convention) file from a file
;              describing the source curvilinear grid.
;           2) Use curvilinear_to_SCRIP to create a SCRIP (convention) file from a file
;              describing the destination (WRF-Hydro) grid.
;           3) Use ESMF_regrid_gen_weights to generate a weight file using a remapping
;              option specified in the command line.
;
; 
; Example Usage    : ncl 'interp_opt="bilinear"' 'srcGridName="input_data/wrfout_d01_2013-09-10_00:00:00"' 'dstGridName="geo_em.d02.nc"' WRF2WRFHydro_generate_weights.ncl
;
;            interp_opt = conserve / bilinear 
;            srcGridName = name of file that contains source grid
;            dstGridName = name of file that contains the destination (WRF-Hydro) grid
;
; NCAR WRF-Hydro Team
; Updated: June 24, 2020   K. FitzGerald
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
  ; Define weight filename.                                       ;
  ;---------------------------------------------------------------;
    wgtFileName = "./WRF2WRFHydro_weight_"+interp_opt+".nc"

  if ( .not.isfilepresent( srcGridName ) ) then
     print( " ... source grid file not found : "+ srcGridName )
     exit
  end if

  if ( .not.isfilepresent( dstGridName ) ) then
     print( " ... destination grid file not found : "+ dstGridName )
     exit
  end if

  ;---------------------------------------------------------------;
  ; Field names for lat and lon coordinates in the source file.   ;
  ;---------------------------------------------------------------;
  LatName = "XLAT"
  LonName = "XLONG"

;----------------------------------------------------------------------
; Convert source grid to a SCRIP convention file.
;----------------------------------------------------------------------
    src_file = addfile(srcGridName,"r")
    vNames   = getfilevarnames( src_file )

    if ( isfilevar( src_file, LatName ) .and. isfilevar( src_file, LonName ) ) then
       src_lat = src_file->$LatName$(0,:,:)
       src_lon = src_file->$LonName$(0,:,:)
    else
       print( " ... no such lat/lon fieldnames" )
       exit
    end if

    Opt                = True
    Opt@SrcRegional    = True
    Opt@ForceOverwrite = True
    Opt@PrintTimings   = True
    Opt@Title          = "WRF"
    Opt@CopyVarAtts    = True
    Opt@CopyVarCoords  = False

    src_SCRIP_filename     = "SCRIP_WRF_"+interp_opt+".nc"
    curvilinear_to_SCRIP( src_SCRIP_filename, src_lat, src_lon, Opt)

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

    dst_SCRIP_filename     = "SCRIP_WRFHydro_"+interp_opt+".nc"
    curvilinear_to_SCRIP( dst_SCRIP_filename, dst_lat, dst_lon,Opt)

    delete(Opt)

;----------------------------------------------------------------------
; Generate the weights that take you from the source grid to 
; destination degree grid.
;----------------------------------------------------------------------
    Opt                      = True
    Opt@InterpMethod         = interp_opt
    Opt@SrcRegional          = True
    Opt@DstRegional          = True
    Opt@ForceOverwrite       = True
    Opt@PrintTimings         = True
    Opt@Debug                = True

    ESMF_regrid_gen_weights( src_SCRIP_filename, dst_SCRIP_filename, wgtFileName, Opt)

    delete(Opt)

;----------------------------------------------------------------------
;----------------------------------------------------------------------
end
