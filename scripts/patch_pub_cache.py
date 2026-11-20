#!/usr/bin/env python3
import os
import re
import sys


def _replace_if_below_36(replacement_prefix: str):
    def _repl(match: re.Match) -> str:
        val = match.group(1)
        if val.isdigit() and int(val) >= 36:
            return match.group(0)
        return f"{replacement_prefix}36"
    return _repl


def patch_pub_cache(pub_dir):
    print(f"[patch_pub_cache] Scanning pub-cache at: {pub_dir}")
    if not os.path.exists(pub_dir):
        print("[patch_pub_cache] pub_dir not found, skipping.")
        return

    val_pat = r'(flutter\.compileSdkVersion|\d+)'

    for root, dirs, files in os.walk(pub_dir):
        # 1. Patch Gradle build files
        for fname in files:
            fpath = os.path.join(root, fname)

            if fname in ('build.gradle', 'build.gradle.kts'):
                try:
                    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                        c = f.read()
                    orig = c
                    if fname == 'build.gradle.kts':
                        c = re.sub(rf'\bcompileSdk\s*=\s*{val_pat}\b', _replace_if_below_36('compileSdk = '), c)
                        c = re.sub(rf'\bcompileSdk\s*\(\s*{val_pat}\s*\)', _replace_if_below_36('compileSdk = '), c)
                        c = re.sub(rf'\bcompileSdkVersion\s*\(\s*{val_pat}\s*\)', _replace_if_below_36('compileSdk = '), c)
                    else:
                        c = re.sub(rf'\bcompileSdk\s*=\s*{val_pat}\b', _replace_if_below_36('compileSdk = '), c)
                        c = re.sub(rf'\bcompileSdk\s+{val_pat}\b', _replace_if_below_36('compileSdk '), c)
                        c = re.sub(rf'\bcompileSdkVersion\s*=\s*{val_pat}\b', _replace_if_below_36('compileSdkVersion = '), c)
                        c = re.sub(rf'\bcompileSdkVersion\s+{val_pat}\b', _replace_if_below_36('compileSdkVersion '), c)
                        c = re.sub(rf'\bcompileSdkVersion\s*\(\s*{val_pat}\s*\)', _replace_if_below_36('compileSdkVersion '), c)
                        c = re.sub(
                            r'^([^\n]*\bcompileSdk[^\n]*)$',
                            lambda m: re.sub(r'([?:]\s*)(?:2\d|3[0-5])\b', r'\g<1>36', m.group(1)),
                            c,
                            flags=re.M,
                        )
                    if c != orig:
                        with open(fpath, 'w', encoding='utf-8') as f:
                            f.write(c)
                        print(f"[patch_pub_cache] Patched compileSdk -> 36: {fpath}")
                except Exception as e:
                    print(f"[patch_pub_cache] Error patching gradle {fpath}: {e}")

            # 2. Patch legacy package attribute in plugin AndroidManifests for AGP 8+
            elif fname == 'AndroidManifest.xml':
                try:
                    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                        c = f.read()
                    c_new = re.sub(r'package="[a-zA-Z0-9_\.]*"', '', c)
                    if c_new != c:
                        with open(fpath, 'w', encoding='utf-8') as f:
                            f.write(c_new)
                except Exception as e:
                    print(f"[patch_pub_cache] Error patching manifest {fpath}: {e}")

            # 3. Patch record_linux.dart cleanly and idempotently
            elif fname == 'record_linux.dart':
                try:
                    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                        lines = f.readlines()

                    new_lines = []
                    found_start_stream = False
                    for line in lines:
                        if 'startStream(' in line:
                            found_start_stream = True

                    for line in lines:
                        # Normalize hasPermission signature for record_platform_interface >= 1.5.0
                        if 'Future<bool> hasPermission(String recorderId)' in line:
                            line = line.replace(
                                'Future<bool> hasPermission(String recorderId)',
                                'Future<bool> hasPermission(String recorderId, {bool request = true})'
                            )

                        # Inject startStream before registerWith ONLY if not already present
                        if 'static void registerWith() {' in line and not found_start_stream:
                            new_lines.append('  @override\n')
                            new_lines.append('  Future<Stream<Uint8List>> startStream(String recorderId, RecordConfig config) => throw UnimplementedError();\n\n')
                            found_start_stream = True

                        new_lines.append(line)

                    with open(fpath, 'w', encoding='utf-8') as f:
                        f.writelines(new_lines)
                    print(f"[patch_pub_cache] Successfully verified and patched {fpath}")
                except Exception as e:
                    print(f"[patch_pub_cache] Error patching record_linux.dart {fpath}: {e}")

if __name__ == '__main__':
    pub_dir = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('PUB_CACHE', os.path.expanduser('~/.pub-cache'))
    patch_pub_cache(pub_dir)
