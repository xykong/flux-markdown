"""Exercise the real appcast generator without signing keys or network writes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
NS = {'s': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}


class AppcastTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'scripts').mkdir()
        for name in ['generate-appcast.sh', 'render-release-notes.cjs', 'write-appcast-item.py']:
            if (ROOT / 'scripts' / name).exists():
                shutil.copy(ROOT / 'scripts' / name, self.root / 'scripts' / name)
        (self.root / 'web-renderer').symlink_to(ROOT / 'web-renderer', target_is_directory=True)
        signer = self.root / 'sign_update'
        signer.write_text('#!/bin/sh\necho \'sparkle:edSignature="fake-signature" length="3"\'\n')
        signer.chmod(0o755)
        (self.root / 'test.dmg').write_bytes(b'dmg')
        (self.root / '.version').write_text('1.2.3')
        (self.root / 'appcast.xml').write_text('''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
<language>zh-CN</language>
<item><title>newer</title><sparkle:shortVersionString>1.3.4</sparkle:shortVersionString><enclosure url="newer" length="9" sparkle:edSignature="unchanged"/><description>newer notes</description></item>
<item><title>older</title><sparkle:shortVersionString>1.1.2</sparkle:shortVersionString><description>older notes</description></item>
</channel></rss>''')
        (self.root / 'CHANGELOG.md').write_text('''## [Unreleased]
- Future
## [1.2.3] - 2026-11-08
### Fixed
- Thanks [@angedell](https://github.com/angedell), @Ctrl-Alb and @3mrr4dy; 中文.
## [1.1.2]
- Wrong version
''')

    def generate(self, answer=''):
        return subprocess.run(['bash', 'scripts/generate-appcast.sh', 'test.dmg'],
                              cwd=self.root, input=answer, text=True, capture_output=True,
                              env=dict(os.environ))

    def items(self):
        return ET.parse(self.root / 'appcast.xml').findall('./channel/item')

    def test_handles_links_and_literal_text_are_data(self):
        changelog = self.root / 'CHANGELOG.md'
        changelog.write_text(changelog.read_text().replace('## [1.1.2]',
            '- Literal `$HOME | \\path @inside` and <script>alert(1)</script> & text.\n## [1.1.2]'))
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        description = self.items()[0].findtext('description')
        for text in ['@Ctrl-Alb', '@3mrr4dy', '中文', '$HOME | \\path @inside',
                     '<a href="https://github.com/angedell">@angedell</a>',
                     '&lt;script&gt;', '&amp; text']:
            self.assertIn(text, description)
        self.assertNotIn('<script>', description)
        self.assertNotIn('Wrong version', description)

    def test_replacing_older_item_preserves_other_items(self):
        original = [ET.tostring(i) for i in self.items()]
        self.assertEqual(self.generate().returncode, 0)
        # Put a newer item before the version being replaced, as in a backfill.
        path = self.root / 'appcast.xml'
        root = ET.parse(path)
        channel = root.getroot().find('channel')
        items = channel.findall('item')
        channel.remove(items[1])
        channel.insert(list(channel).index(items[0]), items[1])
        ET.register_namespace('sparkle', NS['s'])
        root.write(path, encoding='unicode')
        result = self.generate('y\n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        other = [ET.tostring(i) for i in self.items()
                 if i.findtext('s:shortVersionString', namespaces=NS) != '1.2.3']
        self.assertEqual(len(other), 2)
        for before, after in zip(original, other):
            self.assertEqual(ET.tostring(ET.fromstring(before)), ET.tostring(ET.fromstring(after)))

    def test_declining_existing_item_preserves_bytes(self):
        self.assertEqual(self.generate().returncode, 0)
        before = (self.root / 'appcast.xml').read_bytes()
        self.assertEqual(self.generate('n\n').returncode, 0)
        self.assertEqual(before, (self.root / 'appcast.xml').read_bytes())

    def test_does_not_truncate_credit_after_fifty_lines(self):
        (self.root / 'CHANGELOG.md').write_text('## [1.2.3]\n### Fixed\n' +
            '- Detail\n' * 55 + '- Thanks [@last-reporter](https://github.com/last-reporter)\n')
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('@last-reporter', self.items()[0].findtext('description'))


if __name__ == '__main__':
    unittest.main()
