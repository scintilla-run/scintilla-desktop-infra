#!/usr/bin/env python3
import pathlib,re,sys,tomllib
root=pathlib.Path(__file__).resolve().parents[1]
data=tomllib.loads((root/'appliance.toml').read_text())
errors=[]
if data.get('version')!=1: errors.append('version must be 1')
if data.get('profile')!='single-host-desktop-v1': errors.append('unexpected profile')
if data.get('reverse_proxy_required') is not False: errors.append('default path must not require another reverse proxy')
for key in ('ingress_url','daemon_url'):
    if not str(data.get(key,'')).startswith('http://127.0.0.1:'): errors.append(key+' must be loopback')
seen=set()
for c in data.get('component',[]):
    name=c.get('name'); rev=c.get('rev','')
    if not name or name in seen: errors.append('duplicate/missing component name')
    seen.add(name)
    if not re.fullmatch(r'[0-9a-f]{40}',rev): errors.append(str(name)+': rev must be exact SHA')
    if c.get('status') not in {'blocked','candidate','promoted'}: errors.append(str(name)+': invalid status')
    if not str(c.get('repo','')).startswith('https://github.com/scintilla-run/'): errors.append(str(name)+': wrong org')
missing={'desktop-daemon','beam-runner','cli'}-seen
if missing: errors.append('missing: '+','.join(sorted(missing)))
if data.get('ready') and any(c.get('status')!='promoted' for c in data.get('component',[])): errors.append('ready appliance may contain only promoted components')
if errors:
    print('\n'.join('ERROR: '+x for x in errors),file=sys.stderr); raise SystemExit(1)
print('appliance manifest structurally OK; ready='+str(data.get('ready')))
