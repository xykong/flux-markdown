"""Verify an independently compiled reference directory, not MathJax output."""
from pathlib import Path
import json
import re
import sys
import xml.etree.ElementTree as ET

project = Path(__file__).resolve().parents[3]
oracle = Path(sys.argv[1])
manifest = json.loads((project / 'docs/research/issue64/oracle/manifest.json').read_text())
for filename, expected in [('reference', manifest['labelsExpected']),
                           ('identities', manifest['identityLabelsExpected'])]:
    labels = {}
    for line in (oracle / (filename + '.aux')).read_text().splitlines():
        if not line.startswith(r'\newlabel'):
            continue
        key = line.split('{', 1)[1].split('}', 1)[0]
        payload = line.split('}{{', 1)[1]
        labels[key] = (payload[1:] if payload.startswith('{') else payload).split('}', 1)[0]
    assert labels == expected, labels
    log = (oracle / (filename + '.log')).read_text()
    assert not re.search(r'Missing character|LaTeX Warning:|Overfull|Underfull', log)
cases = json.loads((project / 'docs/research/issue64/math-cases.json').read_text())
root = ET.fromstring(next(case['tex'] for case in cases if case['id'] == 'M13'))
ns = {'m': 'http://www.w3.org/1998/Math/MathML'}
powers = root.findall('m:mrow/m:msup', ns)
assert [node.find('m:mi', ns).text for node in powers] == ['x', 'y', 'z']
assert [node.find('m:mn', ns).text for node in powers] == ['2', '2', '2']
assert [node.text for node in root.findall('m:mrow/m:mo', ns)] == ['+', '=']
print('Independent TeX labels/log and original MathML structure passed.')
