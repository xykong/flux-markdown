#!/usr/bin/env python3
"""Prepare (never launch) a disposable Sparkle regression host.

Usage: prepare.py OLD_APP SDK_FRAMEWORK RUNTIME_FRAMEWORK NEW_OUTPUT_DIRECTORY
The runtime is the sole variable between 2.8.1 and 2.9.3 controls. SDK_FRAMEWORK
supplies development headers stripped from released application bundles.
"""
import pathlib
import plistlib
import subprocess
import sys


def run(*args):
    subprocess.run(list(map(str, args)), check=True)


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    old, sdk, runtime, output = map(lambda p: pathlib.Path(p).resolve(), sys.argv[1:])
    info = plistlib.loads((old / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'com.xykong.Markdown':
        sys.exit('Expected a FluxMarkdown source bundle')
    if not (sdk / 'Headers/Sparkle.h').is_file() or not (runtime / 'Sparkle').is_file():
        sys.exit('Expected SDK and runtime Sparkle.framework paths')
    # Refuse overwrites, including existing app bundles and output directories.
    output.mkdir(parents=True, exist_ok=False)
    app = output / 'FluxMarkdown.app'
    contents = app / 'Contents'
    (contents / 'MacOS').mkdir(parents=True)
    (contents / 'Frameworks').mkdir()
    for key in ['NSMainStoryboardFile', 'NSPrincipalClass']:
        info.pop(key, None)
    info['SUEnableAutomaticChecks'] = False
    (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
    run('ditto', runtime, contents / 'Frameworks/Sparkle.framework')
    source = pathlib.Path(__file__).resolve().parent
    run('clang', '-fobjc-arc', '-framework', 'Cocoa', '-framework', 'Sparkle',
        '-F' + str(sdk.parent), '-Wl,-rpath,@executable_path/../Frameworks',
        source / 'Host.m', '-o', contents / 'MacOS/FluxMarkdown')
    run('clang', '-dynamiclib', '-fobjc-arc', '-framework', 'Foundation',
        '-framework', 'ServiceManagement', source / 'OnDemand.m',
        '-o', output / 'OnDemand.dylib')
    run('codesign', '--force', '--deep', '--sign', '-', app)
    print('Prepared only. See README.md before launching:', app)


if __name__ == '__main__':
    main()
