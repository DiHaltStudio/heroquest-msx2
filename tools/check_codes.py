"""Run after make all to check valid codes, all single-letter errors and the secret."""
from pathlib import Path
import os, subprocess
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
import sys
sys.path.insert(0,'tools')
from build_rom import symbols
sym=symbols('build/savecode.sym')
(ROOT/'build/test').mkdir(parents=True,exist_ok=True)
cases=[]
for slot in range(4):
 vals=[19,9,7,13,1,18,200,2,3,4,5,3+19*slot];rs=[27]*6+[2000,8,128,32,32,79];n=0
 for v,r in zip(vals,rs):n=n*r+v
 ds=[];c=7
 for i in range(14):
  d=n%26;n//=26;e=(d+c)%26;ds.append(e);c=e+3+i
 h=slot+1
 for e in ds:h=(31*h+e+1)%676
 ds +=[h//26,h%26]
 cases.append((slot,1,ds))
 for pos in range(16):
  for v in range(26):
   if v==ds[pos]:continue
   bad=ds[:];bad[pos]=v;cases.append((slot,0,bad))
 cases.append((slot,0,[0]*16))
 cases.append((slot,2,[ord(c)-65 for c in 'MENTORLORETOME']))
rows='\n'.join('{%s %s {%s}}'%(s,k,' '.join(map(str,ds))) for s,k,ds in cases)
t='''set ::cs [open "${out}.checks" w]
set ::cases {ROWS}
set ::idx 0
set ::good 0
proc next_code {} {
 if {$::idx == [llength $::cases]} {puts $::cs "PASS $::idx cases"; close $::cs; hq_report; return}
 lassign [lindex $::cases $::idx] ::slot ::kind ds
 debug write_block memory 0x4000 $::module
 poke 0x65F0 $::slot
 set ::hero [expr {0xA9E5+26*$::slot}]
 set ::banner [expr {[peek16 [expr {0xA476+2*$::slot}]]+3}]
 set ::before [debug read_block memory $::hero 26]
 set ::name [debug read_block memory $::banner 6]
 debug write_block memory CODE [binary format cu* $ds]
 reg SP 0x6D70
 if {$::kind==2} {poke 0x6D70 0; poke 0x6D71 0; reg PC SECRET} else {reg PC DECODE}
}
proc result_code {accepted} {
 if {($::kind!=0)!=$accepted} {puts $::cs "FAIL acceptance case $::idx slot=$::slot kind=$::kind"; flush $::cs; hq_report;return}
 if {!$accepted && ([debug read_block memory $::hero 26] ne $::before || [debug read_block memory $::banner 6] ne $::name)} {puts $::cs "FAIL modified rejected hero"; flush $::cs;hq_report;return}
 if {$::kind==1 && ([debug read_block memory $::banner 6] ne "SIGMAR" || [peek16 [expr {$::hero+9}]]!=1000)} {puts $::cs "FAIL decoded data";flush $::cs;hq_report;return}
 if {$::kind==2 && ([debug read_block memory $::banner 6] ne $::name || [peek16 [expr {$::hero+9}]]!=9995 || [peek [expr {$::hero+14}]]!=127)} {puts $::cs "FAIL secret";flush $::cs;hq_report;return}
 incr ::idx
 next_code
}
proc start_codes {} {
 set f [open build/savecode.bin rb];set ::module [read $f];close $f
 debug set_bp BAD {} {result_code 0}
 debug set_bp EXIT {} {result_code 1}
 next_code
}
after time 36 start_codes
'''.replace('ROWS',rows)
for k,v in sorted({'CODE':sym['sc_code'],'SECRET':sym['sc_try_secret'],'DECODE':sym['sc_decode'],'BAD':sym['sc_bad'],'EXIT':sym['sc_exit']}.items(), key=lambda x:-len(x[0])):t=t.replace(k,hex(v))
Path('build/test/codes.tcl').write_text(t)

prefix=ROOT/'build/test/codes'
prefix.with_suffix('.checks').unlink(missing_ok=True)
env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',HQ_OUT=str(prefix),HQ_SECS='1000',HQ_KEYS='18 space/0.5 21 space/0.5 24 space/0.5 28 space/0.5',HQ_TCL='6 {source build/test/codes.tcl}')
r=subprocess.run(['openmsx','-machine','Philips_NMS_8250','-carta','build/heroquest.rom','-romtype','ASCII16','-command','set renderer none','-script','tools/boot_test.tcl'],cwd=ROOT,env=env,capture_output=True,text=True,timeout=60)
assert r.returncode==0,r.stderr
report=prefix.with_suffix('.checks').read_text()
assert f'PASS {len(cases)} cases' in report and 'FAIL' not in report,report
print(report,end='')
