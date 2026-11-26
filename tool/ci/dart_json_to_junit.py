#!/usr/bin/env python3
"""Convert `dart test --file-reporter=json:...` NDJSON output to JUnit XML.

Emits `<testcase classname="<suite_path>" file="<suite_path>" ...>` so CircleCI
reports test results in the Tests tab and records per-file timings for
`circleci tests split --split-by=timings`.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
import os
import sys
import xml.etree.ElementTree as ET


def normalize_suite_path(path: str, prefix: str | None) -> str:
    cleaned = path.strip()
    if cleaned.startswith("./"):
        cleaned = cleaned[2:]
    if prefix:
        norm_prefix = prefix.strip("/")
        if norm_prefix and not cleaned.startswith(f"{norm_prefix}/"):
            return f"{norm_prefix}/{cleaned}"
    return cleaned


def convert(input_path: str, output_path: str, suite_name: str, prefix: str | None) -> None:
    suites: dict[int, str] = {}
    tests: dict[int, dict] = {}
    errors: dict[int, list[dict]] = defaultdict(list)
    done_events: list[dict] = []

    if os.path.exists(input_path):
        with open(input_path, "r", encoding="utf-8", errors="replace") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line.startswith("{"):
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue

                ev_type = event.get("type")
                if ev_type == "suite":
                    suite = event.get("suite") or {}
                    sid = suite.get("id")
                    spath = suite.get("path")
                    if isinstance(sid, int) and isinstance(spath, str):
                        suites[sid] = normalize_suite_path(spath, prefix)
                elif ev_type == "testStart":
                    test = event.get("test") or {}
                    tid = test.get("id")
                    if isinstance(tid, int):
                        tests[tid] = {
                            "name": test.get("name") or f"test_{tid}",
                            "suiteID": test.get("suiteID"),
                            "start_ms": event.get("time") or 0,
                        }
                elif ev_type == "error":
                    tid = event.get("testID")
                    if isinstance(tid, int):
                        errors[tid].append(event)
                elif ev_type == "testDone":
                    done_events.append(event)

    by_suite: dict[str, list[dict]] = defaultdict(list)
    for event in done_events:
        tid = event.get("testID")
        if not isinstance(tid, int) or tid not in tests:
            continue
        result = event.get("result") or "success"
        hidden = bool(event.get("hidden"))
        if hidden and result == "success":
            continue

        info = tests[tid]
        suite_path = suites.get(info.get("suiteID"), "unknown")
        start_ms = info.get("start_ms") or 0
        end_ms = event.get("time") or start_ms
        duration_s = max(0.0, (end_ms - start_ms) / 1000.0)
        by_suite[suite_path].append(
            {
                "id": tid,
                "name": info["name"],
                "suite_path": suite_path,
                "result": result,
                "skipped": bool(event.get("skipped")),
                "duration_s": duration_s,
                "errors": errors.get(tid, []),
            }
        )

    root = ET.Element("testsuites")
    for suite_path in sorted(by_suite):
        cases = by_suite[suite_path]
        failures = sum(1 for c in cases if c["result"] == "failure")
        err_count = sum(1 for c in cases if c["result"] == "error")
        skipped = sum(1 for c in cases if c["skipped"])
        total_time = sum(c["duration_s"] for c in cases)

        ts_el = ET.SubElement(
            root,
            "testsuite",
            {
                "name": f"{suite_name}:{suite_path}",
                "tests": str(len(cases)),
                "failures": str(failures),
                "errors": str(err_count),
                "skipped": str(skipped),
                "time": f"{total_time:.6f}",
            },
        )

        for case in cases:
            tc_el = ET.SubElement(
                ts_el,
                "testcase",
                {
                    "classname": case["suite_path"],
                    "file": case["suite_path"],
                    "name": case["name"],
                    "time": f"{case['duration_s']:.6f}",
                },
            )
            if case["skipped"]:
                ET.SubElement(tc_el, "skipped")
            elif case["result"] in ("failure", "error"):
                tag = "failure" if case["result"] == "failure" else "error"
                msgs = []
                for err in case["errors"]:
                    msg = str(err.get("error") or "").strip()
                    stack = str(err.get("stackTrace") or "").strip()
                    msgs.append(f"{msg}\n{stack}".strip() if stack else msg)
                first_msg = (
                    str(case["errors"][0].get("error") or case["result"])
                    if case["errors"]
                    else case["result"]
                )
                err_el = ET.SubElement(tc_el, tag, {"message": first_msg[:200]})
                err_el.text = "\n\n".join(m for m in msgs if m)

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    tree = ET.ElementTree(root)
    if hasattr(ET, "indent"):
        ET.indent(tree, space="  ")
    tree.write(output_path, encoding="utf-8", xml_declaration=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_json", help="Path to dart test JSON reporter output")
    parser.add_argument("output_xml", help="Path to write JUnit XML")
    parser.add_argument("--suite-name", default="dart", help="Testsuite name prefix")
    parser.add_argument(
        "--suite-prefix",
        default=None,
        help="Optional directory prefix to prepend to relative suite paths",
    )
    args = parser.parse_args(argv)
    convert(args.input_json, args.output_xml, args.suite_name, args.suite_prefix)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
