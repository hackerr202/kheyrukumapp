#!/usr/bin/env python3
import json
import urllib.request


def check_job_details(run_id):
    url = f"https://api.github.com/repos/hackerr202/kheyrukumapp/actions/runs/{run_id}/jobs"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            jobs = data.get("jobs", [])
            for j in jobs:
                print(f"Job: {j['name']} | Conclusion: {j['conclusion']}")
                for step in j.get("steps", []):
                    print(f"  Step: {step['name']} | Status: {step['status']} | Conclusion: {step['conclusion']}")
    except Exception as e:
        print(f"Error fetching jobs: {e}")


if __name__ == "__main__":
    check_job_details(45154706274)
