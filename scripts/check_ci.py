#!/usr/bin/env python3
import json
import time
import urllib.request


def check_latest_run():
    url = "https://api.github.com/repos/hackerr202/kheyrukumapp/actions/runs?per_page=3"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            runs = data.get("workflow_runs", [])
            if not runs:
                print("No runs found.")
                return None
            for r in runs:
                print(
                    f"Run #{r['id']}: {r['name']} | Status: {r['status']} | "
                    f"Conclusion: {r['conclusion']} | SHA: {r['head_sha'][:7]} | "
                    f"Created: {r['created_at']} | URL: {r['html_url']}"
                )
            return runs[0]
    except Exception as e:
        print(f"Error checking GitHub Actions: {e}")
        return None


if __name__ == "__main__":
    check_latest_run()
