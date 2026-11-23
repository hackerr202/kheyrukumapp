#!/usr/bin/env python3
import urllib.request


def fetch_log():
    url = "https://api.github.com/repos/hackerr202/kheyrukumapp/actions/jobs/137624581954/logs"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8", errors="ignore")
            lines = content.splitlines()
            print(f"Total lines in log: {len(lines)}")
            # Find errors
            for i, line in enumerate(lines):
                if any(err in line for err in ["error:", "Error:", "FAILURE:", "Exception:"]):
                    print(f"L{i}: {line}")
                    # print next 5 lines
                    for j in range(1, 6):
                        if i + j < len(lines):
                            print(f"  + {lines[i+j]}")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    fetch_log()
