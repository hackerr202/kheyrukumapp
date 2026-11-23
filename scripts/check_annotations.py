#!/usr/bin/env python3
import json
import urllib.request


def check_annotations():
    url = "https://api.github.com/repos/hackerr202/kheyrukumapp/check-runs/45154706274/annotations"
    # Actually check-runs use the job ID
    job_id = 137624581954
    url = f"https://api.github.com/repos/hackerr202/kheyrukumapp/check-runs/{job_id}/annotations"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            print("Annotations:", data)
    except Exception as e:
        print(f"Error annotations: {e}")


if __name__ == "__main__":
    check_annotations()
