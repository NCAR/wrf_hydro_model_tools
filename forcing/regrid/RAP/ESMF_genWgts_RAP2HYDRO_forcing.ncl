; --------------------------------------------------------------------------- ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Program Name: ESMF_genWgts_RAP2HYDRO_forcing.ncl                           ;
;                                                                             ;
;  National Water Model (NWM) WRF-hydro forcing engine is developed by        ;
;  National Center for Atmospheric Research (NCAR), under the sponsorship     ;
;  of National Water Center (NWC).                                            ;
;                                                                             ;
;   Team Members:                                                             ;
;     NCAR Staff: Linlin Pan, Wei Yu, and David Gochis                        ;
;      NWC/OWP Staff: Brian Cosgrove, Zhengtao Cui, Cham Pham, and James Taft ;
;                                                                             ;
;  This is a ncl program to generate weighting function.                      ;
;                                                                             ;
;  Input: source file, geo file                                               ;
;                                                                             ;
;  Output: weighting function                                                 ;
;                                                                             ;
; For non-fatal errors output is witten to $DATA/logs                         ;
;                                                                             ;
; Author(s)/Contact(s): Linlin Pan, lpan@ucar.edu                             ;
; Origination                                                   Sept., 2015    ;
;                                                                             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;----------------------------------------------------------------------
;----------------------------------------------------------------------
;----------------------------------------------------------------------
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

;---Output (and input) files
   ; srcGridName = "~/nowcast/ncl/STEP_"+RUNNAME+"_coord.nc"
   ; dstGridName = "step_hydro_geo_em.d02.nc"
    wgtFileName = "./"+RUNNAME+"_"+domain_name+"_weight_"+interp_opt+".nc"

  if ( .not.isfilepresent( srcGridName ) ) then
     print( " ... source grid file not found : "+ srcGridName )
     exit
  end if

  if ( .not.isfilepresent( dstGridName ) ) then
     print( " ... source grid file not found : "+ srcGridName )
     exit
  end if

;----------------------------------------------------------------------
; Convert source grid to a SCRIP convention file.
;----------------------------------------------------------------------
    src_file = addfile(srcGridName,"r")
    vNames   = getfilevarnames( src_file )

    src_lat = src_file->gridlat_0(:,:)
    src_lon= src_file->gridlon_0(:,:)

; delete_VarAtts(src_lat, -1)
;    delete_VarAtts(src_lon, -1)

    
    Opt                = True
    Opt@SrcRegional    = True
    Opt@ForceOverwrite = True
    Opt@PrintTimings   = True
    Opt@Title          = RUNNAME
    Opt@CopyVarAtts    = False

        Opt@CopyVarAtts    = True

        Opt@CopyVarCoords  = False
        Opt@CopyVarCoords  = False


    src_SCRIP_filename     = "src_"+RUNNAME+"_"+domain_name+"_"+interp_opt+".nc"
    curvilinear_to_SCRIP( src_SCRIP_filename, src_lat, src_lon, Opt)
    ; unstructured_to_ESMF( src_SCRIP_filename, src_lat, src_lon, Opt)
;---Clean up
    delete(Opt)

;----------------------------------------------------------------------
; Convert destination grid to a SCRIP convention file.
;----------------------------------------------------------------------
    dst_file = addfile(dstGridName,"r")

;    if ( isfilevar( dst_file, "XLAT" ) .and. .not. isfilevar( dst_file, "XLAT_M") ) then
;       dst_lat = dst_file->XLAT(0,:,:)
;       dst_lon = dst_file->XLONG(0,:,:)
;    end if
;
;    if ( isfilevar( dst_file, "XLAT_M" ) .and. .not. isfilevar( dst_file, "XLAT" ) ) then
;       dst_lat = dst_file->XLAT_M(0,:,:)
;       dst_lon = dst_file->XLONG_M(0,:,:)
;    end if

       dst_lat = dst_file->XLAT_M(0,:,:)
       dst_lon = dst_file->XLONG_M(0,:,:)

    Opt                = True
    Opt@DstRegional    = True
    Opt@ForceOverwrite = True
    Opt@PrintTimings   = True
    Opt@Title          = dstGridName

    dst_SCRIP_filename     = "dst_"+RUNNAME+"_"+domain_name+"_"+interp_opt+".nc"
    curvilinear_to_SCRIP( dst_SCRIP_filename, dst_lat, dst_lon,Opt)

;---Clean up
    delete(Opt)

;----------------------------------------------------------------------
; Generate the weights that take you from the source grid to 
; destination degree grid.
;----------------------------------------------------------------------
    Opt                      = True
    Opt@InterpMethod         = interp_opt
;    Opt@InterpMethod         = "conserve"
    Opt@SrcRegional    = True
    Opt@DstRegional          = True
    Opt@ForceOverwrite       = True
    Opt@PrintTimings         = True
    Opt@Debug                = True

    ESMF_regrid_gen_weights( src_SCRIP_filename, dst_SCRIP_filename, wgtFileName, Opt)

    delete(Opt)

;----------------------------------------------------------------------
;----------------------------------------------------------------------
end