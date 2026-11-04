"""Verify Vite's emitted module graph and enumerate original dynamic glyph files."""
import hashlib
import json
import sys
from pathlib import Path

renderer = Path(__file__).resolve().parents[2] / 'web-renderer'
bundle = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else renderer / 'dist'
manifest = json.loads((bundle / '.vite/manifest.json').read_text())
dynamic = renderer / 'node_modules/@mathjax/mathjax-newcm-font/mjs/svg/dynamic'
modules = []

def bundled_file(name):
    path = (bundle / name).resolve()
    if not path.is_relative_to(bundle) or not path.is_file():
        raise ValueError(f'Missing or escaping bundled resource: {name}')
    return path

for key, entry in manifest.items():
    bundled_file(entry['file'])
    for name in entry.get('css', []) + entry.get('assets', []):
        bundled_file(name)
    for dependency in entry.get('imports', []) + entry.get('dynamicImports', []):
        if dependency not in manifest:
            raise ValueError(f'Missing module dependency: {key} -> {dependency}')

for original in sorted(dynamic.glob('*.js')):
    key = original.relative_to(renderer).as_posix()
    if key not in manifest:
        raise ValueError(f'Unbundled SVG glyph module: {key}')
    modules.append(manifest[key]['file'])
if not modules:
    raise ValueError('No upstream dynamic glyph modules found')

licenses = {}
for name in ['MathJax-Apache-2.0.txt', 'MathJax-NOTICE.txt', 'NewComputerModern.txt']:
    packaged = bundled_file('licenses/' + name).read_bytes()
    if packaged != (renderer / 'public/licenses' / name).read_bytes():
        raise ValueError(f'Changed packaged attribution: {name}')
    licenses[name] = hashlib.sha256(packaged).hexdigest()
print(json.dumps({'modules':modules, 'manifestEntries':len(manifest), 'licenses':licenses}, indent=2))
