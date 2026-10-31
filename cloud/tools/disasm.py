# disasm.py LR|GD 0xSTART 0xEND  -> disassemble the original binary (floats annotated)
import sys,os,re,struct,pefile,capstone
p=os.environ['RACERS_ORIG']+('/LEGORacers.exe' if sys.argv[1]=='LR' else '/GolDP.dll')
pe=pefile.PE(p); base=pe.OPTIONAL_HEADER.ImageBase
a,e=int(sys.argv[2],16),int(sys.argv[3],16)
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32)
def fl(m):
    v=int(m.group(0),16)
    try:
        f=struct.unpack('<f',pe.get_data(v-base,4))[0]
        if 1e-6<abs(f)<1e7: return m.group(0)+'{%g}'%f
    except Exception: pass
    return m.group(0)
for i in md.disasm(pe.get_data(a-base,e-a),a): print(hex(i.address),i.mnemonic,re.sub(r'0x[0-9a-f]{6,8}',fl,i.op_str))
