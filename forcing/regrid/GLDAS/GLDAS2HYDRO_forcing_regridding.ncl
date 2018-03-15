;----------------------------------------------------------------------
; GLDAS2WRFHYDRO_forcing_regridding.ncl
;
;
; Project : luzon
;
; Purpose : This is a ncl program to perform remapping 
;           of various GLDAS data fields to WRF-Hydro domain (for luzon).
;
;
; Usage   : ncl 'srcsfcfilename="GLDAS_NOAH025_3H.A20150101.0000.021.nc4"' 'dstGridName="geo_em.d04.nc"' GLDAS2HYDRO_forcing_regridding.ncl  
;
;           srcsfcfilename = filename pattern of the souce GLDAS files.
;                         e.g., "GLDAS_NOAH025_3H.A20150101.0000.021.nc4", ...
; 
; Linlin Pan, 24 June, 2017, lpan@ucar.edu
;
;----------------------------------------------------------------------


load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/ut_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

  function sub_string_double(s:string,i:integer,j:integer)
   begin
     s_char = stringtochar(s)
     sub_str = s_char(i:j)
     return (stringtodouble(chartostring(sub_str)))
   end

  function sub_string_float(s:string,i:integer,j:integer)
   begin
     s_char = stringtochar(s)
     sub_str = s_char(i:j)
     return (stringtofloat(chartostring(sub_str)))
   end

 setfileoption("nc","Format","LargeFile")

;----------------------------------------------------------------------
; User settings
;----------------------------------------------------------------------

  ;---------------------------------------------------------------;
  ; Set source and destination grid filenames.                    ;
  ;---------------------------------------------------------------;
  dirm    = "./"       ; directory where source forcing data resides
  outdir  = "./"      ; directory where regridded forcing data will be placed

  ;---------------------------------------------------------------;
  ; Source model data tination grid filenames.                    ;
  ;---------------------------------------------------------------;
  dt=3600.0   ;forcing data timestep in seconds...

  ;---------------------------------------------------------------;
  ; Source, destination , and weight filenames for generating     ;
  ; ESMF_regridding weights                                       ;
  ;---------------------------------------------------------------;
  wgtFileName_conserve = "./GLDAS_to_WRFHYDRO_weight_conserve.nc"
  wgtFileName_bilinear = "./GLDAS_to_WRFHYDRO_weight_bilinear.nc"

  ;---------------------------------------------------------------;
  ; Data field names from the source file to be regridded         ;
  ;---------------------------------------------------------------;
   P_varname = "Psurf_f_inst"
   T_varname = "Tair_f_inst"
   U_varname = "Wind_f_inst"
   V_varname = "Wind_f_inst"
   Q_varname = "Qair_f_inst"

   PCP1_varname  = "Rainf_f_tavg"
   PCP2_varname  = "PRATE_P8_L1_GLL0_avg"
   PCP3_varname  = "PRATE_P8_L1_GLL0_avg3h"
   PCP4_varname  = "PRATE_P8_L1_GLL0_avg6h"

   DSWR1_varname = "SWdown_f_tavg"
   DSWR2_varname = "DSWRF_P8_L1_GLL0_avg"
   DSWR3_varname = "DSWRF_P8_L1_GLL0_avg3h"
   DSWR4_varname = "DSWRF_P8_L1_GLL0_avg6h"

   DLWR1_varname = "LWdown_f_tavg"
   DLWR2_varname = "DLWRF_P8_L1_GLL0_avg"
   DLWR3_varname = "DLWRF_P8_L1_GLL0_avg3h"
   DLWR4_varname = "DLWRF_P8_L1_GLL0_avg6h"

;----------------------------------------------------------------------
; read in source and destination grid netCDF files
;----------------------------------------------------------------------

  if ( .not.isfilepresent( dstGridName ) ) then
     print( " ... source grid file not found : "+ dstGridName )
     exit
  else 
      dstGridName = "./geo_dst.nc"
  end if

;---  destination grid data
  dstfile     = addfile( dstGridName ,"r")
  dlon2d=dstfile->XLONG_M(0,:,:)
  dlat2d=dstfile->XLAT_M(0,:,:)
  dims=dimsizes(dlat2d)

; get the lat/lon dx/dy information for shortwave downscaling

  nsizes =  dims
  xlat = dstfile->XLAT_M(0,:,:)
  xlon = dstfile->XLONG_M(0,:,:)
  dx   = dstfile@DX
  dy   = dstfile@DY
  cosa = dstfile->COSALPHA(0,:,:)
  sina = dstfile->SINALPHA(0,:,:)
  nx   = nsizes(1)
  ny   = nsizes(0)


;
          if( isfilepresent("lapse.nc") )then
            ff = addfile("lapse.nc","r")
             swaplapse = ff->lapse
             lapse = new((/1, dims(0), dims(1)/),"float")
             lapse(0,:,:) = swaplapse(:,:)
            print("Using narr lapse rate")
          else
             lapse = 6.49
            print("Using constant lapse rate")
          end if
;


  flag=0    ;WRF - flag for removing accum precip...

;----------------------------------------------------------------------
; Open source data files to be regridded...
;----------------------------------------------------------------------
; system("mkdir "+outdir)

;  flxfils = systemfunc ("ls "+dirm+srcflxfilename)    ;list of file names
  sfcfils = systemfunc ("ls "+dirm+srcsfcfilename)    ;list of file names
  num_datfils     = dimsizes(sfcfils)
 setfileoption("nc","Format","NetCDF4")


  do ifil = 0,num_datfils-1,1   ; loop through datafiles one at a time
   
;      datflxfile = addfile( flxfils(ifil)+".grb", "r")
      datsfcfile = addfile( sfcfils(ifil), "r")

;      print( " ... Open flx input file : "+ flxfils(ifil) )
      print( " ... Open sfc input file : "+ sfcfils(ifil) )
   
      names = getfilevarnames(datsfcfile)
	print(names)

     ;----------------------------------------------------------------------
     ; Parse time from filename : merged_AWIP32.2011010100.RS.flx, merged_AWIP32.2011010100.RS.sfc
     ;----------------------------------------------------------------------
      strs = str_split( sfcfils(ifil), "." )
      date_str = str_sub_str(strs(1),"A","")
	hh_str=str_get_cols(strs(2),0,1)
	print(hh_str)
	date_str1=date_str + hh_str
      dtime_map = (/4,2,2,2/)
      date_vec = str_split_by_length( date_str1, dtime_map)
;     print( date_vec )

      yyyy=stringtointeger(date_vec(0))
      mon=stringtointeger(date_vec(1))
      dd=stringtointeger(date_vec(2))
      hh=stringtointeger(date_vec(3))
      xtime = hh*60.0
;     print("time is "+yyyy+" "+mon+" "+dd+" "+hh+" "+xtime)

      yyyy@calendar = "julian"
      julian = int2flt(day_of_year(yyyy,mon,dd))
;     print(julian)
;     print(xtime)

      Times_str = date_vec(0)+"-"+date_vec(1)+"-"+date_vec(2)+"_"+date_vec(3)+":00:00"
      new_string = str_strip(Times_str)
      Times = stringtochar( new_string )
      Times!0 = "DateStrLen"

      valid_time = cd_inv_calendar(toint(date_vec(0)), toint(date_vec(1)), toint(date_vec(2)), toint(date_vec(3)), toint(0) ,toint(0) ,"seconds since 1970-01-01 00:00:00", 0)
;     print("valid_time is "+valid_time)
      valid_time!0 = "Time"

     ;----------------------------------------------------------------------
     ; Open output file
     ;----------------------------------------------------------------------
      ncfile= outdir + date_str1+".GLDAS_DOMAIN1.nc"
      if ( isfilepresent( ncfile ) ) then
         system ("/bin/rm "+ncfile)
      end if
      ncdf= addfile(ncfile,"c")
      filedimdef( ncdf ,"Time",-1,True)
     ;ncdf->lat = dlat2d   ;output lat
     ;ncdf->lon = dlon2d   ;output lon
      ncdf->Times = Times  ;output times
      ncdf->valid_time = valid_time
   
     ;----------------------------------------------------------------------
     ;  Processing...no further mods should be required...
     ;----------------------------------------------------------------------
     do v=1,8
     
        if (v.eq.1) then
           var = datsfcfile->$T_varname$(0,:,:)
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.2) then
           var = datsfcfile->$P_varname$
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.3) then
           var = datsfcfile->$U_varname$(0,:,:)
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.4) then
           var = datsfcfile->$V_varname$(0,:,:)
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.5) then
           var = datsfcfile->$Q_varname$(0,:,:)
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.6) then
         i = 0
         do while(i .le. dimsizes(names)-1)
           if(names(i) .eq. PCP1_varname) then
            var = datsfcfile->$PCP1_varname$ 
           else if(names(i) .eq. PCP2_varname) then
            var = datsfcfile->$PCP2_varname$ 
           else if(names(i) .eq. PCP3_varname) then
            var = datsfcfile->$PCP3_varname$ 
           else if(names(i) .eq. PCP4_varname) then
            var = datsfcfile->$PCP4_varname$ 
           end if
           end if
           end if
           end if
           i = i + 1
         end do
            var = datsfcfile->$PCP1_varname$ 
           wgtFileName = wgtFileName_bilinear
           var@long_name = "RAINRATE"
           var@description = "RAINRATE"
           var@units       = "mm s^-1"
        end if
        if (v.eq.7) then
         i = 0
         do while(i .le. dimsizes(names)-1)
           if(names(i) .eq. DLWR1_varname) then
            var = datsfcfile->$DLWR1_varname$ 
           else if(names(i) .eq. DLWR2_varname) then
            var = datsfcfile->$DLWR2_varname$ 
           else if(names(i) .eq. DLWR3_varname) then
            var = datsfcfile->$DLWR3_varname$ 
           else if(names(i) .eq. DLWR4_varname) then
            var = datsfcfile->$DLWR4_varname$ 
           end if
           end if
           end if
           end if
           i = i + 1
         end do
            var = datsfcfile->$DLWR1_varname$ 
           wgtFileName = wgtFileName_bilinear
        end if
        if (v.eq.8) then
         i = 0
         do while(i .le. dimsizes(names)-1)
           if(names(i) .eq. DSWR1_varname) then
            var = datsfcfile->$DSWR1_varname$ 
           else if(names(i) .eq. DSWR2_varname) then
            var = datsfcfile->$DSWR2_varname$ 
           else if(names(i) .eq. DSWR3_varname) then
            var = datsfcfile->$DSWR3_varname$ 
           else if(names(i) .eq. DSWR4_varname) then
            var = datsfcfile->$DSWR4_varname$ 
           end if
           end if
           end if
           end if
           i = i + 1
         end do
            var = datsfcfile->$DSWR1_varname$ 
           wgtFileName = wgtFileName_bilinear
        end if
     
;      printVarSummary(var)
     
       ;----------------------------------------------------------------------
       ; Define new array and perform regriddding
       ;----------------------------------------------------------------------
        ntimes = 1  ; for GLDAS, there is only one time step in each file
        v4 = new((/ntimes, dims(0), dims(1)/),"float")
        v5 = new((/dims(0), dims(1)/),"float")
       
       ;---Options to pass to ESMF_regrid--------------------;
     
        opt                = True
        opt@WgtFileName    = wgtFileName
        opt@CopyVarAtts    = True
        opt@CopyVarCoords  = False
;        opt@SrcRegional    = True
;        opt@DstRegional    = True
     
       ;---Debug information
         opt@PrintTimings   = True
         opt@Debug          = True
       ;-----------------------------------------------------;
        exist = isfilepresent( wgtFileName )
        if ( .not.exist ) then
;          print( " ... no wgtFile. Run ESMF_genWgts_GLDAS2WRFHYDRO_forcing.ncl first."+" "+wgtFileName )
           exit
        end if
     
        var2d = var
        v5 = ESMF_regrid_with_weights( var2d , wgtFileName, opt)
        v4(0,:,:) = v5(:,:)

       ;----------------------------------------------------------------------
       ; Export interpolated data to new forcing file...
       ;----------------------------------------------------------------------
       
       ;--- change dimension names so that ncks command works appropriately ---;
       v4!0 = "Time"
       v4!1 = "south_north"
       v4!2 = "west_east"
;      printVarSummary(v4)
       
       if (v.eq.1) then
             ncdf->T2D = v4
       else if (v.eq.2) then
             ncdf->PSFC = v4
       else if (v.eq.3) then
              ncdf->U2D = v4
       else if (v.eq.4) then
	       v5=v4*0.
              ncdf->V2D = v5
       else if (v.eq.5) then
             ncdf->Q2D = v4
       else if (v.eq.6) then
              ncdf->RAINRATE = v4
       else if (v.eq.7) then
              ncdf->LWDOWN = v4
       else if (v.eq.8) then
             ncdf->SWDOWN = v4
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
     delete([/valid_time,julian/])
   end do   ; end do for file loop


end
