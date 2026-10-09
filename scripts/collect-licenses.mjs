import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const renderer = join(root, 'web-renderer');
const lock = JSON.parse(readFileSync(join(renderer, 'package-lock.json'), 'utf8'));
const noticeName = /^(?:licen[cs]e|notice|copying|copyright)(?:[._-]|$)/i;

function noticesIn(directory) {
    const notices = [];
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
        if (entry.name === 'node_modules') continue;
        const path = join(directory, entry.name);
        if (entry.isDirectory()) {
            notices.push(...noticesIn(path));
        } else if (entry.isFile() && noticeName.test(entry.name)) {
            notices.push(path);
        }
    }
    return notices.sort();
}

const sections = ['Third-party renderer dependency notices', ''];
let count = 0;
for (const location of Object.keys(lock.packages).sort()) {
    const dependency = lock.packages[location];
    if (!location.startsWith('node_modules/') || dependency.dev || dependency.devOptional) continue;
    const directory = join(renderer, location);
    if (!existsSync(directory)) {
        if (dependency.optional) continue;
        throw new Error(`Missing installed dependency: ${location}`);
    }
    const metadata = JSON.parse(readFileSync(join(directory, 'package.json'), 'utf8'));
    const notices = noticesIn(directory);
    if (notices.length === 0) {
        const readme = readdirSync(directory).sort().find(name => /^readme(?:\.|$)/i.test(name));
        if (!readme) throw new Error(`No license notice or README for ${metadata.name}`);
        notices.push(join(directory, readme));
    }
    sections.push(`${metadata.name} ${metadata.version}`, `License: ${metadata.license ?? dependency.license ?? 'See package notices'}`, '');
    for (const notice of notices) {
        sections.push(notice.slice(directory.length + 1), readFileSync(notice, 'utf8').trim(), '');
    }
    sections.push('----------------------------------------------------------------', '');
    count += 1;
}

mkdirSync(join(root, 'build'), { recursive: true });
writeFileSync(join(root, 'build', 'RENDERER_LICENSES.txt'), sections.join('\n'));
console.log(`Collected license notices for ${count} renderer runtime packages.`);
