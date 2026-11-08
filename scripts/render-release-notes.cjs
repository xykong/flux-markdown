#!/usr/bin/env node
// Reuse the renderer's locked Markdown parser; release prose is data, not code.
const fs = require('node:fs');
const MarkdownIt = require('../web-renderer/node_modules/markdown-it');
const markdown = new MarkdownIt({ html: false, typographer: false });

function renderReleaseNotes(changelog, version) {
    if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error('Invalid release version');
    const sections = changelog.split(/(?=^## \[)/m);
    const section = sections.find(text => text.startsWith(`## [${version}]`));
    if (!section) throw new Error(`Missing CHANGELOG section for ${version}`);
    const body = section.slice(section.indexOf('\n') + 1);
    return '<h2>更新内容</h2>\n' + markdown.render(body) +
        `<p><a href="https://github.com/xykong/flux-markdown/releases/tag/v${version}">查看完整更新日志</a></p>`;
}

module.exports = { renderReleaseNotes };
if (require.main === module) {
    const [, , file, version] = process.argv;
    process.stdout.write(renderReleaseNotes(fs.readFileSync(file, 'utf8'), version));
}
