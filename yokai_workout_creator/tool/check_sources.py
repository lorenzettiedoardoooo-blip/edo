#!/usr/bin/env python3
"""SDK-free integrity checks; NOT a Dart analyzer, compiler or runtime test."""
import json
import re
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]


def balanced(source, name):
    i, size = 0, len(source)
    pairs = {'(': ')', '[': ']', '{': '}'}

    def fail(message):
        raise AssertionError(f'{name}:{source[:i].count(chr(10)) + 1}: {message}')

    def string():
        nonlocal i
        raw = i > 0 and source[i - 1] == 'r'
        quote = source[i]
        delimiter = quote * (3 if source.startswith(quote * 3, i) else 1)
        i += len(delimiter)
        while i < size:
            if source.startswith(delimiter, i):
                i += len(delimiter)
                return
            if not raw and source[i] == '\\':
                i += 2
            elif not raw and source.startswith('${', i):
                i += 2
                code('}')
            else:
                i += 1
        fail('unterminated string')

    def code(until=None):
        nonlocal i
        while i < size:
            if source.startswith('//', i):
                end = source.find('\n', i)
                i = size if end < 0 else end + 1
            elif source.startswith('/*', i):
                i += 2
                depth = 1
                while i < size and depth:
                    if source.startswith('/*', i):
                        depth += 1; i += 2
                    elif source.startswith('*/', i):
                        depth -= 1; i += 2
                    else:
                        i += 1
                if depth:
                    fail('unterminated comment')
            elif source[i] in "\"'":
                string()
            elif source[i] in pairs:
                expected = pairs[source[i]]
                i += 1
                code(expected)
            elif source[i] in ')]}':
                if source[i] != until:
                    fail(f'unexpected {source[i]!r}; expected {until!r}')
                i += 1
                return
            else:
                i += 1
        if until:
            fail(f'missing {until}')
    code()


def main():
    dart = list(ROOT.glob('lib/**/*.dart')) + list(ROOT.glob('test/*.dart'))
    kotlin = list(ROOT.glob('android/**/*.kt')) + list(ROOT.glob('android/**/*.kts'))
    for path in dart + kotlin:
        balanced(path.read_text(), path.relative_to(ROOT))
    for path in dart:
        for imp in re.findall(r"import '([^']+)';", path.read_text()):
            if imp.startswith('dart:') or imp.startswith('package:flutter'):
                continue
            target = ROOT / 'lib' / imp.split('/', 1)[1] if imp.startswith('package:yokai_workout_creator/') else path.parent / imp
            assert target.exists(), f'Missing import {imp} in {path}'
    xml = list(ROOT.glob('android/**/*.xml'))
    for path in xml:
        ElementTree.parse(path)
    dart_methods = set(re.findall(r"invoke(?:List)?Method(?:<[^>]+>)?\('([^']+)'", (ROOT / 'lib/services/platform_bridge.dart').read_text()))
    native_source = (ROOT / 'android/app/src/main/kotlin/it/yokai/yokai_workout_creator/MainActivity.kt').read_text()
    native_methods = set(re.findall(r'"([a-zA-Z]+)" ->', native_source))
    assert dart_methods == native_methods, (dart_methods, native_methods)
    main_manifest = (ROOT / 'android/app/src/main/AndroidManifest.xml').read_text()
    assert 'android.permission.INTERNET' not in main_manifest
    assert 'android:maxSdkVersion="28"' in main_manifest
    assert 'android:exported="false" android:grantUriPermissions="true"' in main_manifest
    assert not list(ROOT.rglob('*.jks'))
    report = {'status': 'passed', 'checks': ['balanced delimiters and strings',
        'local Dart import targets', 'Android XML parsing', 'Dart/native channel method parity',
        'release network permission absent', 'legacy storage permission restricted',
        'share provider not exported', 'no private signing keys'],
        'dart_files': len(dart), 'kotlin_and_gradle_files': len(kotlin), 'xml_files': len(xml),
        'platform_methods': sorted(dart_methods),
        'not_executed': ['flutter analyze', 'flutter test', 'APK build', 'Android device tests', 'visual raster QA']}
    print(json.dumps(report, indent=2))
    (ROOT / 'docs/source-checks.json').write_text(json.dumps(report, indent=2) + '\n')

if __name__ == '__main__':
    main()
