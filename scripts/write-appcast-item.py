"""Insert an already-rendered item as data, without interpreting its contents."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'


def write_item(path, version, item):
    original = path.read_text()
    root = ET.fromstring(original)
    incoming = ET.fromstring(f'<rss xmlns:sparkle="{SPARKLE}">{item}</rss>')
    if len(incoming) != 1 or incoming[0].tag != 'item':
        raise ValueError('Expected exactly one release item')
    version_tag = f'{{{SPARKLE}}}shortVersionString'
    if incoming[0].findtext(version_tag) != version:
        raise ValueError('Release item version mismatch')
    blocks = list(re.finditer(r'<item\b[^>]*>.*?</item>', original, re.S))
    if len(blocks) != len(root.findall('./channel/item')):
        raise ValueError('Ambiguous appcast item boundaries')

    # Preserve all unrelated bytes, including older signatures and descriptions.
    def keep_other(match):
        node = ET.fromstring(f'<rss xmlns:sparkle="{SPARKLE}">{match[0]}</rss>')[0]
        return '' if node.findtext(version_tag) == version else match[0]

    updated = re.sub(r'<item\b[^>]*>.*?</item>', keep_other, original, flags=re.S)
    updated, count = re.subn(r'(<language>.*?</language>)',
                            lambda match: match[0] + '\n\n' + item,
                            updated, count=1, flags=re.S)
    if count != 1:
        raise ValueError('Missing appcast language insertion point')
    ET.fromstring(updated)  # Validate before touching the live feed.
    path.write_text(updated)


if __name__ == '__main__':
    write_item(Path(sys.argv[1]), sys.argv[2], sys.stdin.read())
