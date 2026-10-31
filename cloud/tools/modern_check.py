# Parse changed .cpp files with libclang in MSVC-compat mode, approximating the CI "Current MSVC" job.
# Catches e.g. narrowing in case labels (#570/#575). Known false positive: DirectMusicStream (also fails on master).
import clang.cindex as ci, os, sys
ci.Config.set_library_file(os.path.dirname(ci.__file__)+'/native/libclang.so')
idx=ci.Index.create(); inc=os.path.expanduser('~/vcinc')
for f in sys.argv[1:]:
    tg=['GOLDP'] if f.startswith('GolDP/') else (['LEGORACERS'] if f.startswith('LEGORacers/') else ['GOLDP','LEGORACERS'])
    for t in tg:
        d=['-DBUILDING_GOL','-D_WINDLL'] if t=='GOLDP' else ['-DBUILDING_LEGORACERS','-DDIRECTINPUT_VERSION=0x500']
        i=['-I3rdparty/dx6/inc','-IGolDP/include','-IGolDP','-Icommon/include','-Iutil'] if t=='GOLDP' else ['-I3rdparty/dx6/inc','-ILEGORacers/include','-ILEGORacers','-Icommon/include','-Iutil','-IGolDP/include']
        tu=idx.parse(f,args=['-x','c++','--target=i686-pc-windows-msvc','-fms-extensions','-fms-compatibility','-fms-compatibility-version=19.40','-std=c++14','-D_MBCS','-DWIN32','-D_WINDOWS','-D_DEBUG']+d+i+['-isystem',inc])
        e=[x for x in tu.diagnostics if x.severity>=3]
        print(('modern-compile OK  ' if not e else 'modern-compile ERR ')+t+' '+f+('' if not e else ': '+'; '.join(f'{os.path.basename(str(x.location.file))}:{x.location.line} {x.spelling}' for x in e[:4])))
