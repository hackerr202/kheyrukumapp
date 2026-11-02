#!/usr/bin/env python3
import os
import sys

def patch_pub_cache(pub_dir):
    print(f"[patch_pub_cache] Scanning pub-cache at: {pub_dir}")
    if not os.path.exists(pub_dir):
        print("[patch_pub_cache] pub_dir not found, skipping.")
        return

    for root, dirs, files in os.walk(pub_dir):
        # 1. Patch Gradle build files
        for fname in files:
            fpath = os.path.join(root, fname)

            if fname in ('build.gradle', 'build.gradle.kts'):
                try:
                    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                        c = f.read()
                    orig = c
                    c = c.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 35')
                    c = c.replace('compileSdkVersion flutter.compileSdkVersion', 'compileSdkVersion 35')
                    c = c.replace('compileSdk = 34', 'compileSdk = 35')
                    c = c.replace('compileSdkVersion 34', 'compileSdkVersion 35')
                    if c != orig:
                        with open(fpath, 'w', encoding='utf-8') as f:
                            f.write(c)
                except Exception as e:
                    print(f"[patch_pub_cache] Error patching gradle {fpath}: {e}")

            # 2. Patch legacy package attribute in plugin AndroidManifests for AGP 8+
            elif fname == 'AndroidManifest.xml':
                try:
                    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                        c = f.read()
                    import re
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
