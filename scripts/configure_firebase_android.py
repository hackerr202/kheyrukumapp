#!/usr/bin/env python3
import base64
import json
import os
import re


def load_google_services_json() -> str | None:
    env_val = os.environ.get("GOOGLE_SERVICES_JSON", "").strip()
    if env_val:
        raw = env_val if env_val.startswith("{") else base64.b64decode(env_val).decode("utf-8")
        json.loads(raw)
        print("[configure_firebase_android] Loaded google-services.json from GOOGLE_SERVICES_JSON env.")
        return raw

    repo_cfg = os.path.join("android_config", "google-services.json")
    if os.path.exists(repo_cfg):
        with open(repo_cfg, "r", encoding="utf-8") as f:
            raw = f.read().strip()
        if raw:
            json.loads(raw)
            print(f"[configure_firebase_android] Loaded {repo_cfg}.")
            return raw

    return None


def configure_gradle_kts(has_google_services: bool) -> None:
    app_kts = os.path.join("android", "app", "build.gradle.kts")
    settings_kts = os.path.join("android", "settings.gradle.kts")

    if os.path.exists(app_kts):
        with open(app_kts, "r", encoding="utf-8") as f:
            content = f.read()

        if "isCoreLibraryDesugaringEnabled" not in content:
            content = content.replace(
                "compileOptions {",
                "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
                1,
            )
        if "multiDexEnabled" not in content:
            content = content.replace(
                "defaultConfig {",
                "defaultConfig {\n        multiDexEnabled = true",
                1,
            )
        content = content.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 35")
        content = content.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 35")
        content = content.replace("minSdk = flutter.minSdkVersion", "minSdk = 23")
        content = re.sub(r"minSdk\s*=\s*2[012]\b", "minSdk = 23", content)

        if "desugar_jdk_libs" not in content:
            content += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'

        if has_google_services and "com.google.gms.google-services" not in content:
            content = re.sub(
                r'(id\("dev\.flutter\.flutter-gradle-plugin"\))',
                r'\1\n    id("com.google.gms.google-services")',
                content,
                count=1,
            )

        with open(app_kts, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"[configure_firebase_android] Updated {app_kts}")

    if has_google_services and os.path.exists(settings_kts):
        with open(settings_kts, "r", encoding="utf-8") as f:
            scontent = f.read()
        if "com.google.gms.google-services" not in scontent:
            scontent = re.sub(
                r'(plugins\s*\{)',
                r'\1\n    id("com.google.gms.google-services") version "4.4.2" apply false',
                scontent,
                count=1,
            )
            with open(settings_kts, "w", encoding="utf-8") as f:
                f.write(scontent)
            print(f"[configure_firebase_android] Updated {settings_kts}")

    # Legacy Groovy fallback if Flutter ever generates .gradle files
    app_groovy = os.path.join("android", "app", "build.gradle")
    if os.path.exists(app_groovy) and not os.path.exists(app_kts):
        with open(app_groovy, "r", encoding="utf-8") as f:
            gcontent = f.read()
        if "coreLibraryDesugaringEnabled" not in gcontent:
            gcontent = gcontent.replace(
                "compileOptions {",
                "compileOptions {\n        coreLibraryDesugaringEnabled true",
                1,
            )
        if "multiDexEnabled" not in gcontent:
            gcontent = gcontent.replace(
                "defaultConfig {",
                "defaultConfig {\n        multiDexEnabled true",
                1,
            )
        gcontent = gcontent.replace("compileSdkVersion flutter.compileSdkVersion", "compileSdkVersion 35")
        gcontent = gcontent.replace("targetSdkVersion flutter.targetSdkVersion", "targetSdkVersion 35")
        gcontent = gcontent.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 23")
        if "desugar_jdk_libs" not in gcontent:
            gcontent += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'
        if has_google_services and "com.google.gms.google-services" not in gcontent:
            gcontent += '\napply plugin: "com.google.gms.google-services"\n'
        with open(app_groovy, "w", encoding="utf-8") as f:
            f.write(gcontent)
        print(f"[configure_firebase_android] Updated {app_groovy}")


def main() -> None:
    gs_json = load_google_services_json()
    has_gs = gs_json is not None

    if has_gs:
        dest = os.path.join("android", "app", "google-services.json")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(gs_json)
        print(f"[configure_firebase_android] Wrote {dest}")
    else:
        print(
            "[configure_firebase_android] No google-services.json provided yet "
            "(skipping com.google.gms.google-services plugin; local alerts remain active)."
        )

    configure_gradle_kts(has_gs)


if __name__ == "__main__":
    main()
