#!/usr/bin/env python3
"""Create validated git commits with generated messages."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path


def run(cmd: list[str], cwd: Path, check: bool = True, capture: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        check=check,
        text=True,
        capture_output=capture,
    )


def git(args: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(["git", *args], cwd=cwd, check=check)


def repo_root() -> Path:
    result = git(["rev-parse", "--show-toplevel"], Path.cwd())
    return Path(result.stdout.strip())


def ensure_git_repo(root: Path) -> None:
    if not (root / ".git").exists():
        raise SystemExit("error: not inside a git repository")


def has_make_target(root: Path, target: str) -> bool:
    makefile = root / "Makefile"
    if not makefile.exists():
        return False
    pattern = re.compile(rf"^{re.escape(target)}\s*:", re.MULTILINE)
    return pattern.search(makefile.read_text()) is not None


def stage_changes(root: Path, stage_all: bool) -> None:
    if stage_all:
        git(["add", "-A"], root)


def has_staged_changes(root: Path) -> bool:
    result = git(["diff", "--cached", "--quiet"], root, check=False)
    return result.returncode != 0


def detected_checks(root: Path) -> list[list[str]]:
    checks: list[list[str]] = []
    if (root / "selene.toml").exists() and (root / "lua").exists():
        checks.append(["selene", "lua"])
    if has_make_target(root, "tests"):
        checks.append(["make", "tests"])
    return checks


def run_checks(root: Path, checks: list[list[str]]) -> None:
    if not checks:
        raise SystemExit("error: no validation checks were discovered for this repository")

    failures: list[tuple[list[str], subprocess.CompletedProcess[str] | None, str | None]] = []
    for cmd in checks:
        print(f"==> Running {' '.join(cmd)}")
        try:
            result = run(cmd, cwd=root, check=False)
        except FileNotFoundError as exc:
            failures.append((cmd, None, str(exc)))
            continue
        if result.returncode == 0:
            continue
        failures.append((cmd, result, None))

    if failures:
        print("\nCommit blocked because validation failed.\n", file=sys.stderr)
        for cmd, result, error_text in failures:
            print(f"$ {' '.join(cmd)}", file=sys.stderr)
            if error_text:
                print(error_text, file=sys.stderr)
                continue
            if result and result.stdout:
                print(result.stdout, file=sys.stderr)
            if result and result.stderr:
                print(result.stderr, file=sys.stderr)
        raise SystemExit(1)


def staged_name_status(root: Path) -> list[tuple[str, str]]:
    output = git(["diff", "--cached", "--name-status", "--find-renames"], root).stdout.strip()
    changes: list[tuple[str, str]] = []
    if not output:
        return changes

    for line in output.splitlines():
        parts = line.split("\t")
        status = parts[0]
        path = parts[-1]
        changes.append((status, path))
    return changes


def staged_diff(root: Path) -> str:
    return git(["diff", "--cached", "--unified=0"], root).stdout


def classify_path(path: str) -> str:
    lowered = path.lower()
    if lowered.startswith(".github/workflows/"):
        return "ci"
    if lowered.endswith(".md"):
        return "docs"
    if "test" in lowered or "spec" in lowered:
        return "tests"
    if lowered.endswith((".toml", ".yml", ".yaml", ".json")):
        return "config"
    if lowered.endswith((".lua", ".py", ".js", ".ts", ".go", ".rs")):
        return "source"
    return "other"


def infer_type(changes: list[tuple[str, str]], diff_text: str) -> str:
    kinds = Counter(classify_path(path) for _, path in changes)
    source_files = [path for _, path in changes if classify_path(path) == "source"]
    added_source_files = [path for status, path in changes if status.startswith("A") and classify_path(path) == "source"]

    if kinds and kinds.keys() <= {"docs"}:
        return "docs"
    if kinds and kinds.keys() <= {"ci"}:
        return "ci"
    if kinds and kinds.keys() <= {"tests"}:
        return "test"
    if kinds and kinds.keys() <= {"config", "other"}:
        return "chore"
    if added_source_files:
        return "feat"

    added_functions = re.findall(r"^\+\s*function\s+([A-Za-z0-9_.:]+)", diff_text, re.MULTILINE)
    removed_functions = re.findall(r"^-\s*function\s+([A-Za-z0-9_.:]+)", diff_text, re.MULTILINE)
    if added_functions and not removed_functions:
        return "feat"
    if source_files and not added_source_files and added_functions == removed_functions:
        return "refactor"
    if source_files:
        return "fix"
    return "chore"


def infer_scope(changes: list[tuple[str, str]]) -> str | None:
    scopes: list[str] = []
    for _, path in changes:
        parts = Path(path).parts
        if not parts:
            continue
        if parts[0] == "lua" and len(parts) > 1:
            scopes.append(parts[1])
        elif parts[0] == ".github" and len(parts) > 1:
            scopes.append("ci")
        elif parts[0] == "scripts":
            scopes.append("scripts")
        else:
            scopes.append(parts[0].removesuffix(Path(parts[0]).suffix))

    if not scopes:
        return None
    return Counter(scopes).most_common(1)[0][0]


def summarize_targets(changes: list[tuple[str, str]]) -> str:
    preferred: list[str] = []
    for _, path in changes:
        p = Path(path)
        if p.name.lower().startswith("readme"):
            preferred.append("README")
            continue
        if p.suffix in {".lua", ".py", ".sh"}:
            preferred.append(p.stem.replace("_", "-"))
            continue
        if p.parts and p.parts[0] == ".github":
            preferred.append("workflow configuration")
            continue
        preferred.append(p.name)

    unique: list[str] = []
    for item in preferred:
        if item not in unique:
            unique.append(item)

    if not unique:
        return "repository changes"
    if len(unique) == 1:
        return unique[0]
    if len(unique) == 2:
        return f"{unique[0]} and {unique[1]}"
    return f"{unique[0]}, {unique[1]}, and related changes"


def build_subject(commit_type: str, scope: str | None, target: str) -> str:
    actions = {
        "feat": f"add {target}",
        "fix": f"update {target} behavior",
        "refactor": f"refactor {target}",
        "docs": f"update {target}",
        "test": f"expand {target} coverage",
        "ci": f"update {target}",
        "chore": f"update {target}",
    }
    subject = actions.get(commit_type, f"update {target}")
    if scope:
        return f"{commit_type}({scope}): {subject}"
    return f"{commit_type}: {subject}"


def build_body(changes: list[tuple[str, str]], checks: list[list[str]]) -> str:
    files = [path for _, path in changes]
    body_lines = [
        f"- files: {', '.join(files[:5])}" + ("..." if len(files) > 5 else ""),
        f"- checks: {'; '.join(' '.join(cmd) for cmd in checks)}",
    ]
    return "\n\n" + "\n".join(body_lines)


def generate_message(root: Path, checks: list[list[str]]) -> str:
    changes = staged_name_status(root)
    diff_text = staged_diff(root)
    commit_type = infer_type(changes, diff_text)
    scope = infer_scope(changes)
    target = summarize_targets(changes)
    subject = build_subject(commit_type, scope, target)
    return subject + build_body(changes, checks)


def detect_host(remote_url: str) -> str:
    lowered = remote_url.lower()
    if "github" in lowered:
        return "GitHub"
    if "gitlab" in lowered:
        return "GitLab"
    return "remote"


def current_branch(root: Path) -> str:
    result = git(["rev-parse", "--abbrev-ref", "HEAD"], root)
    branch = result.stdout.strip()
    if branch == "HEAD":
        raise SystemExit("error: detached HEAD; specify a branch before pushing")
    return branch


def push_commit(root: Path, remote: str) -> None:
    branch = current_branch(root)
    remote_url = git(["remote", "get-url", remote], root).stdout.strip()
    host = detect_host(remote_url)
    print(f"==> Pushing to {host} ({remote}/{branch})")
    run(["git", "push", remote, branch], cwd=root, check=True, capture=False)


def commit(root: Path, message: str) -> None:
    run(["git", "commit", "-m", message.splitlines()[0], *sum([["-m", line] for line in message.split("\n\n")[1:]], [])], cwd=root)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate and create a git commit with a generated message.")
    parser.add_argument("--all", action="store_true", help="Stage all tracked and untracked changes before validation.")
    parser.add_argument("--push", action="store_true", help="Push the new commit to the current branch on the remote.")
    parser.add_argument("--remote", default="origin", help="Remote name to push to (default: origin).")
    parser.add_argument("--dry-run", action="store_true", help="Run checks and print the generated commit message without committing.")
    parser.add_argument("--message", help="Use a custom commit subject/body instead of generating one.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = repo_root()
    ensure_git_repo(root)
    os.chdir(root)

    stage_changes(root, args.all)
    if not has_staged_changes(root):
        print("error: no staged changes found. Stage changes first or pass --all.", file=sys.stderr)
        return 1

    checks = detected_checks(root)
    run_checks(root, checks)

    message = args.message or generate_message(root, checks)
    print("==> Commit message")
    print(message)

    if args.dry_run:
        return 0

    commit(root, message)

    if args.push:
        push_commit(root, args.remote)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
