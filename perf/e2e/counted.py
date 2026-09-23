import subprocess, os, json, re, hashlib
ROOT='/data/projects/toon_bend'; S='/data/tmp/claude-1000/-data-projects-toon-bend/9e91730b-d91a-4f9e-8b28-923307a5f8cb/scratchpad/'
PORT=S+'final2c33e64/toon'; ORACLE=S+'arms2/z/toon'; O3=S+'arms2/o3/toon'
DOCS=['github_events','apache_builds','twitter','citm_catalog','gsoc_2018','canada']
def irefs(cmd):
    r=subprocess.run(['valgrind','--tool=cachegrind','--cache-sim=no','--cachegrind-out-file=/dev/null']+cmd,
                     capture_output=True, text=True)
    m=re.search(r'I refs:\s+([\d,]+)', r.stderr)
    return int(m.group(1).replace(',','')) if m else None
def out_sha(cmd):
    r=subprocess.run(cmd, capture_output=True)
    return hashlib.sha256(r.stdout).hexdigest()[:16], r.returncode
rows=[]
for d in DOCS:
    j=f'{ROOT}/perf/e2e/corpus/{d}.json'
    if not os.path.exists(j): print('skip',d); continue
    t=S+d+'.cnt.toon'
    if not os.path.exists(t):
        with open(t,'wb') as fh: fh.write(subprocess.run([ORACLE,'--encode',j],capture_output=True).stdout)
    size=os.path.getsize(j)
    for mode,inp in (('encode',j),('decode',t)):
        pa=[PORT,'--threads','1','--',f'--{mode}',inp]; oa=[ORACLE,f'--{mode}',inp]; o3a=[O3,f'--{mode}',inp]
        ps,pr=out_sha(pa); os_,orc=out_sha(oa)
        if ps!=os_ or pr!=orc:
            print(f'{d}/{mode}: OUTPUT DIFFERS — skipping'); continue
        pi,oi,o3i=irefs(pa),irefs(oa),irefs(o3a)
        rows.append(dict(doc=d,mode=mode,bytes=size,port=pi,oracle_z=oi,oracle_o3=o3i,
                         ratio_z=round(pi/oi,2),ratio_o3=round(pi/o3i,2),sha=ps))
        print(f"{d:16s} {mode:7s} port {pi:>13,}  z {oi:>12,}  ratio {pi/oi:5.2f}x   o3 {pi/o3i:5.2f}x")
open(S+'counted_e2e.json','w').write(json.dumps(rows,indent=1))
