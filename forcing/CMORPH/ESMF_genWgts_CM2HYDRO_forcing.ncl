;----------------------------------------------------------------------
; NCAR Command Language Version 6.1.2
;
; ESMF_genWgts_CM2HYDRO_forcing.ncl 
;
; Project : IOC
;
; Purpose :
;           This is an NCL/ESMF file for generating src and dst SCRIP files
;           and weight file for regridding from a CMORPH grid to a
;           HYDRO model domain
; 
; Usage    : ncl 'RUNNAME="BASELINE"' 'interp_opt="bilinear"' 'domain_name="d01"' \
;                'srcGridName="./BASELINE_d01_coord.nc"' \
;               ESMF_genWgts_WRF_HYDRO_forcing.ncl 
;
;            RUNNAME = unique name for the wrf run
;            interp_opt = conserve / bilinear / patch
;            domain_name= name of source domain (will be used to generate the output weight filename)
;            srcGridName = filename (with full path) to read source grid coordinates
;                          either XLAT_M/XLONG_M or XLAT/XLONG must exist in the data file
;
;For questions send email to: lpan@ucar.edu
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

    src_lat = src_file->lat(:)
    src_lon= src_file->lon(:)

; delete_VarAtts(src_lat, -1)
;    delete_VarAtts(src_lon, -1)

    
    Opt                = True
    Opt@SrcRegional    = False
    Opt@ForceOverwrite = True
    Opt@PrintTimings   = True
    Opt@Title          = RUNNAME
    Opt@CopyVarAtts    = False
;    Opt@LargeFile      = True

        Opt@CopyVarAtts    = True

        Opt@CopyVarCoords  = False
        Opt@CopyVarCoords  = False


    src_SCRIP_filename     = "src_"+RUNNAME+"_"+domain_name+"_"+interp_opt+".nc"
    ;curvilinear_to_SCRIP( src_SCRIP_filename, src_lat, src_lon, Opt)
    ; unstructured_to_ESMF( src_SCRIP_filename, src_lat, src_lon, Opt)
    rectilinear_to_SCRIP( src_SCRIP_filename, src_lat, src_lon, Opt)
;---Clean up
    delete(Opt)

;----------------------------------------------------------------------
; Convert destination grid to a SCRIP convention file.
;----------------------------------------------------------------------
    dst_file = addfile(dstGridName,"r")

       dst_lat = dst_file->XLAT_M(0,:,:)
       dst_lon = dst_file->XLONG_M(0,:,:)

    Opt                = True
    Opt@DstRegional    = True
    Opt@ForceOverwrite = True
    Opt@PrintTimings   = True
    Opt@Title          = dstGridName
;    Opt@LargeFile      = True

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
    Opt@SrcRegional    = True 
    Opt@DstRegional          = True
    Opt@ForceOverwrite       = True
    Opt@PrintTimings         = True
    Opt@Debug                = True
;    Opt@LargeFile      = True

    ESMF_regrid_gen_weights( src_SCRIP_filename, dst_SCRIP_filename, wgtFileName, Opt)

    delete(Opt)

;----------------------------------------------------------------------
;----------------------------------------------------------------------
end
