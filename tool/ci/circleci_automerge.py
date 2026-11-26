#!/usr/bin/env python3
"""CircleCI auto-merge step for GitHub Pull Requests.

Runs after `ci-pass` on non-main branches. Safely squash-merges the open PR
for the current branch/SHA once all gates pass:
  - GITHUB_TOKEN (or GH_TOKEN) is configured in CircleCI env vars
  - PR is open, non-draft, same-repo, and matches CIRCLE_SHA1 (when set)
  - PR carries the `automerge` label (or AUTOMERGE_ALL=true)
  - PR is mergeable (not dirty, blocked, or behind)
  - No latest review is CHANGES_REQUESTED
  - All external commit statuses and check runs on head.sha succeed
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_BASE = "https://api.github.com"
ALLOWED_CONCLUSIONS = {"success", "neutral", "skipped"}
IGNORED_CHECK_NAMES = {"ci/circleci: auto-merge", "auto-merge"}


class GitHubClient:
    def __init__(self, token: str) -> None:
        self.token = token

    def request(
        self, method: str, path: str, body: dict | None = None
    ) -> tuple[int, dict | list | None]:
        url = path if path.startswith("http") else f"{API_BASE}{path}"
        data = json.dumps(body).encode("utf-8") if body is not None else None
        headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {self.token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "bloom-circleci-automerge",
        }
        if data is not None:
            headers["Content-Type"] = "application/json"

        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw = resp.read().decode("utf-8")
                return resp.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as err:
            raw = err.read().decode("utf-8", errors="replace")
            try:
                parsed = json.loads(raw) if raw else None
            except json.JSONDecodeError:
                parsed = {"message": raw}
            return err.code, parsed


def find_pr_number(
    gh: GitHubClient, owner: str, repo: str, branch: str, pr_url: str
) -> int | None:
    if pr_url:
        match = re.search(r"/pull/(\d+)(?:$|[/?#])", pr_url)
        if match:
            return int(match.group(1))

    if not branch:
        return None

    head = urllib.parse.quote(f"{owner}:{branch}", safe="")
    status, data = gh.request(
        "GET", f"/repos/{owner}/{repo}/pulls?state=open&head={head}&per_page=10"
    )
    if status != 200 or not isinstance(data, list) or not data:
        return None
    return data[0].get("number")


def check_reviews_ok(
    gh: GitHubClient, owner: str, repo: str, pr_number: int
) -> tuple[bool, str]:
    status, reviews = gh.request(
        "GET", f"/repos/{owner}/{repo}/pulls/{pr_number}/reviews?per_page=100"
    )
    if status != 200 or not isinstance(reviews, list):
        return False, f"Failed to fetch reviews (HTTP {status})."

    latest_by_user: dict[str, str] = {}
    for review in reviews:
        user = (review.get("user") or {}).get("login")
        state = review.get("state")
        if user and state in {"APPROVED", "CHANGES_REQUESTED", "DISMISSED"}:
            latest_by_user[user] = state

    blocking = [u for u, s in latest_by_user.items() if s == "CHANGES_REQUESTED"]
    if blocking:
        return False, f"Changes requested by: {', '.join(sorted(blocking))}."
    return True, "No blocking reviews."


def wait_for_external_checks(
    gh: GitHubClient,
    owner: str,
    repo: str,
    sha: str,
    timeout_seconds: int = 30,
) -> tuple[bool, str]:
    deadline = time.monotonic() + timeout_seconds
    while True:
        st_code, combined = gh.request(
            "GET", f"/repos/{owner}/{repo}/commits/{sha}/status"
        )
        ck_code, checks = gh.request(
            "GET", f"/repos/{owner}/{repo}/commits/{sha}/check-runs?per_page=100"
        )
        if st_code != 200 or not isinstance(combined, dict):
            return False, f"Failed to fetch commit statuses (HTTP {st_code})."
        if ck_code != 200 or not isinstance(checks, dict):
            return False, f"Failed to fetch check runs (HTTP {ck_code})."

        statuses = combined.get("statuses") or []
        bad_statuses = [
            f"{s.get('context')}={s.get('state')}"
            for s in statuses
            if s.get("context") not in IGNORED_CHECK_NAMES
            and s.get("state") in {"failure", "error"}
        ]
        if bad_statuses:
            return False, f"Failing commit statuses: {', '.join(bad_statuses)}."

        pending_statuses = [
            s.get("context")
            for s in statuses
            if s.get("context") not in IGNORED_CHECK_NAMES
            and s.get("state") == "pending"
        ]

        check_runs = checks.get("check_runs") or []
        bad_checks = []
        pending_checks = []
        for run in check_runs:
            name = run.get("name") or ""
            if name.lower() in IGNORED_CHECK_NAMES:
                continue
            if run.get("status") != "completed":
                pending_checks.append(f"{name}:{run.get('status')}")
            elif run.get("conclusion") not in ALLOWED_CONCLUSIONS:
                bad_checks.append(f"{name}={run.get('conclusion')}")

        if bad_checks:
            return False, f"Failing check runs: {', '.join(bad_checks)}."

        if not pending_statuses and not pending_checks:
            return True, "All external commit statuses and check runs succeeded."

        if time.monotonic() >= deadline:
            pending_all = pending_statuses + pending_checks
            return False, f"Timed out waiting for pending checks: {', '.join(pending_all)}."

        time.sleep(5)


def run(args: argparse.Namespace) -> int:
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN") or ""
    if not token:
        print(
            "auto-merge: GITHUB_TOKEN is not set in CircleCI. "
            "Add a GITHUB_TOKEN (with repo scope) in CircleCI Project Settings -> "
            "Environment Variables to enable automatic PR merging."
        )
        return 0

    owner = args.owner or os.environ.get("CIRCLE_PROJECT_USERNAME") or ""
    repo = args.repo or os.environ.get("CIRCLE_PROJECT_REPONAME") or ""
    branch = args.branch or os.environ.get("CIRCLE_BRANCH") or ""
    expected_sha = args.sha if args.sha is not None else os.environ.get("CIRCLE_SHA1", "")
    pr_url = args.pr_url or os.environ.get("CIRCLE_PULL_REQUEST") or ""

    if not owner or not repo:
        print("auto-merge: Missing CIRCLE_PROJECT_USERNAME or CIRCLE_PROJECT_REPONAME; skipping.")
        return 0

    if branch == "main":
        print("auto-merge: On main branch; skipping.")
        return 0

    gh = GitHubClient(token)
    pr_number = find_pr_number(gh, owner, repo, branch, pr_url)
    if not pr_number:
        print(f"auto-merge: No open PR found for branch '{branch}'; skipping.")
        return 0

    code, pr = gh.request("GET", f"/repos/{owner}/{repo}/pulls/{pr_number}")
    if code != 200 or not isinstance(pr, dict):
        print(f"auto-merge: Failed to load PR #{pr_number} (HTTP {code}): {pr}", file=sys.stderr)
        return 1

    if pr.get("state") != "open":
        print(f"auto-merge: PR #{pr_number} is {pr.get('state')}; skipping.")
        return 0

    if pr.get("draft"):
        print(f"auto-merge: PR #{pr_number} is a draft; skipping.")
        return 0

    head_repo = ((pr.get("head") or {}).get("repo") or {}).get("full_name")
    base_repo = ((pr.get("base") or {}).get("repo") or {}).get("full_name")
    if not head_repo or head_repo != base_repo:
        print(f"auto-merge: PR #{pr_number} is from a fork ({head_repo}); skipping.")
        return 0

    head_sha = (pr.get("head") or {}).get("sha") or ""
    if expected_sha and head_sha != expected_sha:
        print(
            f"auto-merge: PR #{pr_number} head moved to {head_sha[:7]} "
            f"(build is for {expected_sha[:7]}); skipping."
        )
        return 0

    automerge_all = os.environ.get("AUTOMERGE_ALL", "").lower() in {"1", "true", "yes"}
    target_label = os.environ.get("AUTOMERGE_LABEL", "automerge").lower()
    labels = [str(l.get("name") or "").lower() for l in (pr.get("labels") or [])]
    if not automerge_all and target_label not in labels:
        print(
            f"auto-merge: PR #{pr_number} does not have '{target_label}' label "
            "(and AUTOMERGE_ALL!=true); skipping."
        )
        return 0

    for _ in range(3):
        if pr.get("mergeable") is not None:
            break
        time.sleep(3)
        code, refreshed = gh.request("GET", f"/repos/{owner}/{repo}/pulls/{pr_number}")
        if code == 200 and isinstance(refreshed, dict):
            pr = refreshed

    mergeable = pr.get("mergeable")
    mergeable_state = pr.get("mergeable_state")
    if mergeable is False or mergeable_state in {"dirty", "blocked", "behind"}:
        print(
            f"auto-merge: PR #{pr_number} is not mergeable "
            f"(mergeable={mergeable}, state={mergeable_state}); skipping."
        )
        return 0

    reviews_ok, reviews_msg = check_reviews_ok(gh, owner, repo, pr_number)
    if not reviews_ok:
        print(f"auto-merge: PR #{pr_number}: {reviews_msg}")
        return 0

    checks_ok, checks_msg = wait_for_external_checks(
        gh, owner, repo, head_sha, timeout_seconds=args.wait_seconds
    )
    if not checks_ok:
        print(f"auto-merge: PR #{pr_number}: {checks_msg}")
        return 0

    merge_method = os.environ.get("AUTOMERGE_METHOD", "squash")
    if args.dry_run:
        print(
            f"auto-merge [dry-run]: PR #{pr_number} ({head_sha[:7]}) passed all gates "
            f"and would {merge_method}-merge into {((pr.get('base') or {}).get('ref'))}."
        )
        return 0

    merge_code, merge_resp = gh.request(
        "PUT",
        f"/repos/{owner}/{repo}/pulls/{pr_number}/merge",
        body={"sha": head_sha, "merge_method": merge_method},
    )
    if merge_code not in {200, 201}:
        print(
            f"auto-merge: Merge failed for PR #{pr_number} (HTTP {merge_code}): {merge_resp}",
            file=sys.stderr,
        )
        return 1

    print(f"auto-merge: Successfully {merge_method}-merged PR #{pr_number} ({head_sha[:7]}).")

    head_ref = (pr.get("head") or {}).get("ref") or ""
    base_ref = (pr.get("base") or {}).get("ref") or ""
    if head_ref and head_ref != base_ref:
        encoded_ref = urllib.parse.quote(head_ref, safe="/")
        del_code, _ = gh.request(
            "DELETE", f"/repos/{owner}/{repo}/git/refs/heads/{encoded_ref}"
        )
        if del_code in {200, 204}:
            print(f"auto-merge: Deleted branch '{head_ref}'.")
        else:
            print(f"auto-merge: Could not delete branch '{head_ref}' (HTTP {del_code}).")

    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", default="")
    parser.add_argument("--repo", default="")
    parser.add_argument("--branch", default="")
    parser.add_argument("--sha", default=None)
    parser.add_argument("--pr-url", default="")
    parser.add_argument("--wait-seconds", type=int, default=30)
    parser.add_argument("--dry-run", action="store_true")
    return run(parser.parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
