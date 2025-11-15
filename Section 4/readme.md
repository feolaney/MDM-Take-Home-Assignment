# macadmins recent repositories report

This document covers:
- What the script collects and how it filters data
- Requirements to run it locally
- The command to generate the CSV report

---

## 1) Prerequisites
- **Python 3.8+**
  Ships with the standard library modules this script uses.
- **Network access**
  Needed to call the GitHub REST API (no auth token required).

---

## 2) What the script does
`macadmins_recent_repos.py` targets a GitHub organization (default `macadmins`) and:
1. Calls the public REST API, iterating through each result page until every repository record is collected.
2. Converts the ISO8601 `updated_at` field into Python `datetime` objects and discards entries older than 30 days from “now”.
3. Sorts the remaining repositories by most recent activity before writing `report.csv` with columns for name, description, star count, and last update timestamp.

---

## 3) Usage
Run from this directory:

```bash
python3 macadmins_recent_repos.py
```

Override the organization or output path with the script’s optional arguments if needed.
