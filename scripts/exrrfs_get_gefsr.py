import os, sys, time, urllib, socket
from urllib import request
from urllib.error import URLError, HTTPError
from datetime import datetime, timedelta
import numpy as np

attempts = 1 

getdate = sys.argv[1]
year = int(getdate[0:4])
month = int(getdate[4:6])
day = int(getdate[6:8])
hour = int(getdate[8:10])
julday = (datetime(year,month,day,hour) - datetime(year,1,1,0)).days+1

ens_index = sys.argv[2]
datapath = sys.argv[3]
landsfc = sys.argv[4]

minfhr = int(sys.argv[5])
fcst_length = int(sys.argv[6])
maxfhr = minfhr + fcst_length
lbcint = sys.argv[7]
fhrint = int(lbcint.split(':')[0])

vars = ['tmp','ugrd','vgrd','spfh','hgt','pres','tsoil','soilw','weasd']

levs = {}
levs['tmp'] = ['pres','pres_abv700mb','2m','sfc']
levs['ugrd'] = ['pres','pres_abv700mb','hgt']
levs['vgrd'] = ['pres','pres_abv700mb','hgt']
levs['spfh'] = ['pres','pres_abv700mb','2m']
levs['hgt'] = ['pres','pres_abv700mb','sfc']
levs['pres'] = ['sfc','msl']
levs['tsoil'] = ['bgrnd']
levs['soilw'] = ['bgrnd']
levs['weasd'] = ['sfc']

if int(ens_index)==1:
    member = "c00"
else:
    member = "p%02d"%(int(ens_index)-1)



datadir = datapath + '/' + ens_index + '/%i'%year+'%02d'%month+'%02d'%day+'%02d'%hour
os.system('rm -rf '+datadir) 
need_to_run = 0
for fhr in np.arange(minfhr,maxfhr+1,fhrint):
  #fhrdir = datadir + '/f%03d'%fhr
  fhrfile = datapath + '/' + ens_index + '/%02d'%(year-2000)+'%03d'%julday+'%02d'%hour+'00%04d'%fhr
  if not os.path.exists(fhrfile):
    need_to_run = 1
  #os.system('rm -f '+fhrfile) 

if need_to_run==1:
  for var in vars:
    for lev in levs[var]:

      localfile = datadir+'/'+var+'_'+lev+'_%i'%year+'%02d'%month+'%02d'%day+'%02d'%hour+'_'+ens_index+'.grib2'
      if not os.path.exists(localfile):
        awsfile = 'https://noaa-gefs-retrospective.s3.amazonaws.com/GEFSv12/reforecast/%i'%year+'/%i'%year+'%02d'%month+'%02d'%day+'%02d'%hour+'/'+member+'/Days%3A1-10/'+var+'_'+lev+'_%i'%year+'%02d'%month+'%02d'%day+'%02d'%hour+'_'+member+'.grib2'
        print('AWS file: %s %s'%(var,lev),awsfile)
        os.system('mkdir -p '+datadir)
        attempt = 1
        success = 0
        os.system('rm -f '+localfile+'.tmp')
        while attempt <= attempts and success == 0:
          try:
            aws_size = urllib.request.urlopen(awsfile).info()['Content-Length']
            urllib.request.urlretrieve(awsfile,localfile+'.tmp')
          except HTTPError:
            print('AWS file not retrieved')
            attempt = attempts + 1
          if os.path.exists(localfile+'.tmp'):
            if os.stat(localfile+'.tmp').st_size == int(aws_size):
              success = 1
              os.system('mv '+localfile+'.tmp '+localfile)
              for fhr in np.arange(minfhr,maxfhr+1,fhrint):
                fhrdir = datadir + '/f%03d'%fhr
                os.system('mkdir -p '+fhrdir)
                fhrfile = fhrdir + '/' + var+'_'+lev+'_%i'%year+'%02d'%month+'%02d'%day+'%02d'%hour+'_'+ens_index+'_f%03d'%fhr+'.grib2'
                if not os.path.exists(fhrfile):
                  wgrib2_command = 'wgrib2 '+localfile+' -match ":%i'%fhr+' hour|:%i'%(fhr-3)+'-%i'%fhr+' hour|:%i'%(fhr-6)+'-%i'%fhr+' hour" -GRIB '+fhrfile
                  print(wgrib2_command)
                  os.system(wgrib2_command)
                  if os.stat(fhrfile).st_size < 100:
                    os.system('rm -f '+fhrfile)
            else:
              print('Retrieved incomplete file.  Removing...')
              os.system('rm -f '+localfile+'.tmp')
          else:
            attempt += 1
        if attempt > attempts and success == 0:
          print('Failed to retrieve file from AWS')

  for fhr in np.arange(minfhr,maxfhr+1,fhrint):
    os.system('wgrib2 -set_date %i'%year+'%02d'%month+'%02d'%day+'%02d'%hour+' -set_ftime "%i'%fhr+' hour fcst" '+landsfc+' -GRIB '+datadir+'/landsfc.tmp')
    fhrdir = datadir + '/f%03d'%fhr
    fhrfile = datapath + '/' + ens_index + '/%02d'%(year-2000)+'%03d'%julday+'%02d'%hour+'00%04d'%fhr
    os.system('rm -f '+fhrfile)
    os.system('cat '+datadir+'/landsfc.tmp '+fhrdir+'/*.grib2 > '+fhrfile)
    os.system('rm -rf '+datadir+'/f%03d'%fhr+' '+datadir+'/*.grib2 '+datadir+'/landsfc.tmp')

  os.system('rmdir '+datadir)
  quit()

else:
  print("Data already staged, exiting")
  quit()

