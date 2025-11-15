#!/usr/bin/env python3
"""
macadmins_recent_repos.py

Fetch all public repositories from a GitHub organization (default macadmins),
filter those updated within the last N days (default 30), and save a report
to CSV or TXT. No authentication required. Optional GITHUB_TOKEN supported
to raise rate limits.
"""

import sys
import json
import csv
import argparse
import os
from datetime import datetime, timedelta, timezone
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

API_URL = "https://api.github.com/orgs/{org}/repos?per_page={per_page}&type=public&sort=updated&direction=desc"

HEADERS = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "macadmins-recent-repos-script",
    "X-GitHub-Api-Version": "2022-11-28",
}

# Optional token to increase rate limits. Not required.
_token = os.getenv("GITHUB_TOKEN")
if _token:
    HEADERS["Authorization"] = f"Bearer {_token}"

def parse_link_header(value: str):
    """Parse an RFC 5988 Link header into a dict of rel -> url."""
    links = {}
    if not value:
        return links
    parts = value.split(",")
    for part in parts:
        section = part.strip().split(";")
        if len(section) < 2:
            continue
        url_part = section[0].strip()
        if url_part.startswith("<") and url_part.endswith(">"):
            url = url_part[1:-1]
        else:
            url = url_part
        rel = None
        for param in section[1:]:
            param = param.strip()
            if param.startswith("rel="):
                rel = param[4:].strip('"')
        if rel:
            links[rel] = url
    return links

def fetch_page(url: str):
    """Fetch a single page of repos. Returns (items, next_url, remaining_limit)."""
    req = Request(url, headers=HEADERS)
    with urlopen(req) as resp:
        data = resp.read()
        encoding = resp.headers.get_content_charset() or "utf-8"
        obj = json.loads(data.decode(encoding))
        link = resp.headers.get("Link")
        next_url = parse_link_header(link).get("next")
        remaining = resp.headers.get("X-RateLimit-Remaining")
        return obj, next_url, int(remaining) if remaining is not None else None

def iso_to_dt(s: str) -> datetime:
    """Convert GitHub ISO timestamp to aware datetime in UTC."""
    # Example format: 2025-06-10T07:25:32Z
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)

def write_csv(rows, path: str):
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["repository", "description", "stars", "last_updated"])
        for r in rows:
            w.writerow([
                r["name"],
                r["description"] or "",
                r["stargazers_count"],
                r["updated_at"]
            ])

def write_txt(rows, path: str):
    header = f"{'Repository':40}  {'Stars':>5}  {'Last updated':20}  Description"
    lines = [header, "-" * len(header)]
    for r in rows:
        name = (r["name"] or "")[:40].ljust(40)
        stars = str(r["stargazers_count"]).rjust(5)
        updated = r["updated_at"]
        desc = (r["description"] or "").replace("\n", " ").strip()
        lines.append(f"{name}  {stars}  {updated:20}  {desc}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

def main():
    parser = argparse.ArgumentParser(
        description="Generate a report of organization repositories updated in the last N days."
    )
    parser.add_argument("--org", default="macadmins", help="GitHub organization login")
    parser.add_argument("--days", type=int, default=30, help="Lookback window in days")
    parser.add_argument("--out", default="report.csv", help="Output path, .csv or .txt")
    parser.add_argument("--per-page", type=int, default=100, help="Repos per page for pagination")
    args = parser.parse_args()

    threshold = datetime.now(timezone.utc) - timedelta(days=args.days)
    url = API_URL.format(org=args.org, per_page=args.per_page)

    collected = []
    try:
        while url:
            page, next_url, remaining = fetch_page(url)

            # Stop immediately if the unauthenticated rate limit is exhausted
            if remaining is not None and remaining <= 0:
                print("GitHub API rate limit reached. Try later or set GITHUB_TOKEN.", file=sys.stderr)
                sys.exit(2)

            # Keep repos updated within the window
            for repo in page:
                try:
                    updated_dt = iso_to_dt(repo["updated_at"])
                except Exception:
                    continue
                if updated_dt >= threshold:
                    collected.append(repo)

            # Early stop optimization when results are sorted by updated desc
            if page:
                oldest_on_page = iso_to_dt(page[-1]["updated_at"])
                if oldest_on_page < threshold:
                    break

            url = next_url

    except HTTPError as e:
        body = e.read().decode(errors="ignore")
        print(f"HTTP error {e.code}: {body}", file=sys.stderr)
        sys.exit(1)
    except URLError as e:
        print(f"Network error: {e}", file=sys.stderr)
        sys.exit(1)

    # Order output by most recently updated
    collected.sort(key=lambda r: r.get("updated_at", ""), reverse=True)

    out_lower = args.out.lower()
    if out_lower.endswith(".txt"):
        write_txt(collected, args.out)
    else:
        if not out_lower.endswith(".csv"):
            args.out += ".csv"
        write_csv(collected, args.out)

    print(f"Wrote {len(collected)} repositories to {args.out}")

if __name__ == "__main__":
    main()