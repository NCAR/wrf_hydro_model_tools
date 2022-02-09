# Import required libraries
import pandas as pd
import xarray as xr
import xesmf as xe

# Open RDRS CaPA dataset
ds = xr.open_dataset('RDRS_CaPA24hr_forcings_final.nc')


# Create new dataset from the relevant subset of variables and complete the necessary unit conversions
ds_new = ds[['RDRS_PR0_SFC','RDRS_UUC_40m','RDRS_VVC_40m',
             'RDRS_HU_40m','RDRS_TT_40m','RDRS_FB_SFC',
             'RDRS_FI_SFC','RDRS_P0_SFC']]

ds_new.rename({'RDRS_PR0_SFC':'RAINRATE','RDRS_UUC_40m':'U2D',
              'RDRS_VVC_40m':'V2D','RDRS_HU_40m':'Q2D',
              'RDRS_TT_40m':'T2D','RDRS_FB_SFC':'SWDOWN',
              'RDRS_FI_SFC':'LWDOWN','RDRS_P0_SFC':'PSFC'},inplace=True)

ds_new['RAINRATE'] = ds_new.RAINRATE*1000.0 / (60.0*60.0)    # convert from m/hr to kg/m^2/s
ds_new['U2D'] = ds_new['U2D']*0.514444                       # convert from knots to m/s
ds_new['V2D'] = ds_new['V2D']*0.514444                       # convert from knots to m/s
ds_new['T2D'] = ds_new['T2D'] + 273.16                       # convert from degrees C to K
ds_new['PSFC'] = ds_new['PSFC']*100.0                        # convert from mb to Pa


# Open geogrid file for WRF-Hydro domain, rename dimensions, and drop time dimension
ds_out = xr.open_dataset('geo_em.d01.nc')
ds_out.rename({'XLONG_M': 'lon', 'XLAT_M': 'lat'}, inplace=True)
ds_out['lat'] = ds_out['lat'].sel(Time=0, drop=True)
ds_out['lon'] = ds_out['lon'].sel(Time=0, drop=True)


# Create regridder object
regridder = xe.Regridder(ds_new, ds_out, 'bilinear', reuse_weights=False)


# Iterate over data variables and regrid each to the WRF-Hydro domain
for var in ds_new.data_vars:
    ds_new[var] = regridder(ds_new[var])


# Drop unnecessary dimensions and attributes
ds_new = ds_new.drop(('rlat','rlon','lat','lon'))
ds_new.attrs = []


# Open spatial metadata file for domain
ds_sm = xr.open_dataset('GEOGRID_LDASOUT_Spatial_Metadata.nc')


# Update metadata

# Add x and y coordinates
ds_new.coords['west_east'] = ds_sm.x.values
ds_new.coords['south_north'] = ds_sm.y.values
ds_new = ds_new.rename({'west_east': 'x', 'south_north': 'y'})

# Add units
ds_new.RAINRATE.attrs['units'] = 'mm/s'
ds_new.U2D.attrs['units'] = 'm/s'
ds_new.V2D.attrs['units'] = 'm/s'
ds_new.Q2D.attrs['units'] = 'kg/kg'
ds_new.T2D.attrs['units'] = 'K'
ds_new.LWDOWN.attrs['units'] = 'W/m^2'
ds_new.SWDOWN.attrs['units'] = 'W/m^2'
ds_new.PSFC.attrs['units'] = 'Pa'

# Add ESRI projection string
for var in ds_new.data_vars:
    ds_new[var].attrs['esri_pe_string'] = ds_sm.crs.attrs['esri_pe_string']


# Write to files
dates = pd.to_datetime(ds_new.time.values)
for i in range(dates.size):
    ds_new.isel(time=[i]).to_netcdf(dates[i].strftime('%Y%m%d%H')+'00.LDASIN_DOMAIN1')

