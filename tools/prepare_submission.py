"""Package the tested working tree and APK for handover using Python 3."""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKS = {
    "campaign": ("campaign.log", r"CAMPAIGN SMOKE checks=(\d+) failures=(\d+)"),
    "prototype": ("prototype.log", r"PROTOTYPE SMOKE checks=(\d+) failures=(\d+)"),
    "station": ("station.log", r"STATION SMOKE checks=(\d+) failures=(\d+)"),
    "quiet_signal": ("quiet-signal.log", r"QUIET SIGNAL SMOKE checks=(\d+) failures=(\d+)"),
}
SCREENSHOTS = (
    "orbit", "cabin", "phase", "biosad-berries", "life-support-stock",
    "ship-journal", "settings-audio", "quiet-signal-campaign", "takeoff",
)
EXTRA_EVIDENCE = (
    "import.log", "android-export.log", "apk-signature.log", "apk-manifest.log",
    "android-runtime.log", "android-input.png", "android-resume.png",
)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_files():
    names = git("ls-files", "--cached", "--others", "--exclude-standard", "-z")
    files = []
    for name in sorted(set(names.split("\0")) - {""}):
        path = ROOT / name
        parts = Path(name).parts
        if any(part in {".git", ".godot", "work", "builds", "__pycache__"} for part in parts):
            continue
        if path.name.startswith(".env") and path.name != ".env.example":
            continue
        if path.suffix.lower() in {".jks", ".keystore", ".apk", ".aab", ".pck", ".pyc"}:
            continue
        if path.is_symlink():
            raise RuntimeError(f"Review source symlink before packaging: {name}")
        if path.is_file():
            files.append((name, path))
    return files


def plain_text(markdown):
    lines = []
    for line in markdown.splitlines():
        if line.startswith("```"):
            continue
        if line.startswith("|"):
            cells = [cell.strip().replace("`", "") for cell in line.strip("|").split("|")]
            if not all(re.fullmatch(r":?-+:?", cell) for cell in cells):
                lines.extend(["", cells[0], *(f"  {cell}" for cell in cells[1:])])
            continue
        line = re.sub(r"^#+\s+", "", line)
        lines.append(line.replace("`", "").replace("**", ""))
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--checks", type=Path, default=ROOT / "work/submission-checks")
    parser.add_argument("--materials", type=Path, default=ROOT / "builds/submission-materials")
    parser.add_argument("--output", type=Path, default=ROOT / "builds/submission/kerna-rc1")
    args = parser.parse_args()
    apk = args.apk.resolve(strict=True)
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / "builds"):
        raise RuntimeError("Output must be inside the project's builds directory")
    if output.exists():
        raise RuntimeError("Output already exists; select a new --output directory")

    results = {}
    for key, (filename, pattern) in CHECKS.items():
        log = args.checks / filename
        matches = re.findall(pattern, log.read_text(encoding="utf-8", errors="replace"))
        if not matches or int(matches[-1][1]) != 0 or int(matches[-1][0]) == 0:
            raise RuntimeError(f"Missing or failed check: {key}")
        results[key] = {"checks": int(matches[-1][0]), "failures": 0}
    with zipfile.ZipFile(apk) as archive:
        if any(re.search(r"(^|/)voice_.*\.(wav|ogg)", name, re.I) for name in archive.namelist()):
            raise RuntimeError("Voice audio found in APK")
    files = source_files()
    source_hashes = {name: sha256(path) for name, path in files}
    for filename in ("kerna-presentation.pptx", "kerna-demo.mp4"):
        if not (args.materials / filename).is_file():
            raise RuntimeError(f"Missing submission material: {filename}")
    output.mkdir(parents=True)
    shutil.copy2(apk, output / "kerna-android.apk")
    for filename in ("kerna-presentation.pptx", "kerna-demo.mp4"):
        shutil.copy2(args.materials / filename, output / filename)
    shutil.copytree(ROOT / "submission", output / "instructions")
    documents = {"ai-use-report": "kerna-ai-report.txt", "technical-documentation": "kerna-technical-documentation.txt"}
    for stem, filename in documents.items():
        source = ROOT / "submission" / f"{stem}.md"
        (output / filename).write_text(
            plain_text(source.read_text(encoding="utf-8")), encoding="utf-8-sig"
        )
    (output / "checks").mkdir()
    for name in [*(filename for filename, _ in CHECKS.values()), *EXTRA_EVIDENCE]:
        shutil.copy2(args.checks / name, output / "checks" / name)
    (output / "screenshots").mkdir()
    for name in SCREENSHOTS:
        shutil.copy2(ROOT / f"work/campaign/{name}.png", output / f"screenshots/{name}.png")
    with zipfile.ZipFile(output / "kerna-source.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for name, path in files:
            archive.write(path, f"GamejamCyberhand/{name}")
    changed = [name for name, path in files if sha256(path) != source_hashes[name]]
    if changed:
        raise RuntimeError(f"Source changed while packaging: {changed}")
    manifest = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "version": "0.9.0-rc1",
        "engine": "4.4.1.stable.official.49a5bc7b6",
        "branch": git("branch", "--show-current").strip(),
        "base_commit": git("rev-parse", "HEAD").strip(),
        "working_tree_changes": git("status", "--porcelain").splitlines(),
        "source_sha256": source_hashes,
        "checks": results,
        "voice_audio": "removed; opening mix regenerated from effects only",
        "physical_device_test": "not performed for this build",
        "physical_prosthesis_test": "not performed",
    }
    (output / "build.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    deliverables = sorted(path for path in output.rglob("*") if path.is_file())
    lines = [f"{sha256(path)}  {path.relative_to(output).as_posix()}" for path in deliverables]
    (output / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Prepared {output} with {len(files)} source files")


if __name__ == "__main__":
    main()
