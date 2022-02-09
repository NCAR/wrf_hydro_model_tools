import xarray as xr
import xesmf as xe
from matplotlib import pyplot as plt

ds = xr.open_dataset('../hourly/2011/2011010112_024.nc')
ds['precip_rate'] = ds.PR0_SFC*1000.0 / (60.0*60.0)

ds_out = xr.open_dataset('geo_em.d01.nc')
ds_out.rename({'XLONG_M': 'lon', 'XLAT_M': 'lat'}, inplace=True)
ds_out['lat'] = ds_out['lat'].sel(Time=0, drop=True)
ds_out['lon'] = ds_out['lon'].sel(Time=0, drop=True)

regridder = xe.Regridder(ds, ds_out, 'bilinear')

dr = ds.precip_rate
dr_out = regridder(dr)

dr_out[0].plot()
plt.axis('scaled')
plt.show()

