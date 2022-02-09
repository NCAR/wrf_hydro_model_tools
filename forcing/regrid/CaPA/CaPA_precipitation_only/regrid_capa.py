import pandas as pd
import xarray as xr
import xesmf as xe
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('input_files')
args = parser.parse_args()

ds_sm = xr.open_dataset('GEOGRID_LDASOUT_Spatial_Metadata.nc',autoclose=True)

ds = xr.open_mfdataset(args.input_files)
ds['precip_rate'] = ds.PR0_SFC*1000.0 / (60.0*60.0)

ds_out = xr.open_dataset('geo_em.d01.nc')
ds_out.rename({'XLONG_M': 'lon', 'XLAT_M': 'lat'}, inplace=True)
ds_out['lat'] = ds_out['lat'].sel(Time=0, drop=True)
ds_out['lon'] = ds_out['lon'].sel(Time=0, drop=True)

regridder = xe.Regridder(ds, ds_out, 'bilinear', reuse_weights=True)

dr = ds.precip_rate
dr_out = regridder(dr)

dr_out.coords['west_east'] = ds_sm.x.values
dr_out.coords['south_north'] = ds_sm.y.values
dr_out = dr_out.rename({'west_east': 'x', 'south_north': 'y'})
dr_out.attrs['esri_pe_string'] = ds_sm.ProjectionCoordinateSystem.attrs['esri_pe_string']
dr_out.attrs['units'] = 'mm/s'

dates = pd.to_datetime(dr_out.time.values)
for i in range(dates.size):
    dr_out.isel(time=[i]).to_netcdf(dates[i].strftime('%Y%m%d%H')+'00.PRECIP_FORCING.nc')

