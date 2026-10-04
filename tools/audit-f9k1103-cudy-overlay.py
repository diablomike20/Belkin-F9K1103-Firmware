#!/usr/bin/env python3
import pathlib, re, sys

if len(sys.argv) != 3:
    raise SystemExit("usage: audit-f9k1103-cudy-overlay.py ROOT OUT")

root=pathlib.Path(sys.argv[1])
out=pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

files=list((root/'usr/lib/lua/luci').rglob('*'))+list((root/'www').rglob('*'))
files=[p for p in files if p.is_file() and p.suffix != '.so']

needles=[
    'mcore','cmagent','cmsd','bdinfo','hcshd','gcom','cellular',
    'quectel','modem','cwmp','tr069','mosquitto','rpcd','ubus',
    'iwinfo','wireless','vpn','samba','usb','opkg'
]
hits={n:[] for n in needles}
requires={}

for p in files:
    rel=str(p.relative_to(root))
    try:
        data=p.read_bytes()
    except Exception:
        continue
    strings=[m.group().decode('latin1','replace')
             for m in re.finditer(rb'[ -~]{3,}',data)]
    joined='\n'.join(strings)
    low=joined.lower()
    for n in needles:
        if n in low:
            hits[n].append(rel)
    mods=set()
    for s in strings:
        for pat in (
            r'require\s*["\']([A-Za-z0-9_./-]+)',
            r'require\s*\(?\s*["\']([A-Za-z0-9_./-]+)',
        ):
            mods.update(m.group(1) for m in re.finditer(pat,s))
    if mods:
        requires[rel]=sorted(mods)

with (out/'DEPENDENCY-HITS.tsv').open('w') as f:
    f.write('dependency\tcount\tpaths\n')
    for n in needles:
        f.write(f"{n}\t{len(hits[n])}\t{' ; '.join(hits[n])}\n")

with (out/'REQUIRE-STRINGS.tsv').open('w') as f:
    f.write('path\trequires\n')
    for p in sorted(requires):
        f.write(p+'\t'+' ; '.join(requires[p])+'\n')

risk = {
    'BLOCK_CELLULAR': set(hits['cellular']+hits['gcom']+hits['quectel']+hits['modem']),
    'ADAPT_MCORE': set(hits['mcore']),
    'ADAPT_CLOUD': set(hits['cmagent']+hits['cmsd']+hits['mosquitto']),
    'ADAPT_IDENTITY': set(hits['bdinfo']),
    'DROP_TR069': set(hits['cwmp']+hits['tr069']),
}
with (out/'PORT-RISK-MATRIX.tsv').open('w') as f:
    f.write('class\tcount\tpaths\n')
    for k,v in risk.items():
        f.write(f"{k}\t{len(v)}\t{' ; '.join(sorted(v))}\n")
