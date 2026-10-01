#!/usr/bin/env python3
"""Build protected N3Z artifacts without destroying source files."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path

from obfuscator import PROFILES, obfuscate_code

TARGET_NAMES = ("n3z.lua", "n3z-dock.lua", "n3z-compat.lua", "init.lua")

AUTO_THRESHOLD_KIB = 28
AUTO_FORCE_MAX = {"init.lua", "n3z.lua", "n3z-compat.lua"}
AUTO_FORCE_PERFORMANCE = {"n3z-dock.lua"}


def iter_targets(root: Path):
    for name in TARGET_NAMES:
        path = root / name
        if path.exists():
            yield path
    modules = root / "modules"
    if modules.exists():
        yield from sorted(modules.glob("*.lua"))


def read_source(source_path: Path, root: Path, source_ref: str | None) -> str:
    if source_ref is None:
        return source_path.read_text(encoding="utf-8")
    relative = source_path.relative_to(root).as_posix()
    data = subprocess.check_output(
        ["git", "-C", str(root), "show", f"{source_ref}:{relative}"]
    )
    return data.decode("utf-8")


def choose_profile(
    relative_path: Path,
    input_bytes: int,
    requested_profile: str,
    threshold_bytes: int,
) -> str:
    if requested_profile != "auto":
        return requested_profile

    relative = relative_path.as_posix().lower()

    if relative in AUTO_FORCE_MAX:
        return "max"
    if relative in AUTO_FORCE_PERFORMANCE:
        return "performance"

    if relative.startswith("modules/"):
        return "max" if input_bytes <= threshold_bytes else "performance"

    return "max" if input_bytes <= threshold_bytes else "performance"


def protect_file(
    source_path: Path,
    output_path: Path,
    requested_profile: str,
    root: Path,
    source_ref: str | None,
    threshold_bytes: int,
) -> tuple[int, int, str]:
    source = read_source(source_path, root, source_ref)
    if "Protected by N3Z Shield" in source:
        hint = " (choose an earlier --source-ref)" if source_ref else ""
        raise RuntimeError(f"refusing to protect already-protected source: {source_path}{hint}")

    input_bytes = len(source.encode("utf-8"))
    relative = source_path.relative_to(root)
    selected_profile = choose_profile(
        relative, input_bytes, requested_profile, threshold_bytes
    )
    protected = obfuscate_code(source, profile=selected_profile)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(protected, encoding="utf-8", newline="\n")
    return input_bytes, len(protected.encode("utf-8")), selected_profile


def main() -> None:
    parser = argparse.ArgumentParser(description="Build N3Z Shield v3 protected artifacts")
    parser.add_argument("--profile", choices=["auto", *sorted(PROFILES)], default="auto")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument(
        "--source-ref",
        default=None,
        help="read plaintext inputs from a Git revision instead of the working tree",
    )
    parser.add_argument(
        "--auto-threshold-kib",
        type=int,
        default=AUTO_THRESHOLD_KIB,
        help="auto mode size threshold for selecting max vs performance",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="overwrite source files (not recommended; ignored when --output-dir is used)",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    if args.output_dir:
        output_root = Path(args.output_dir).resolve()
    elif args.in_place:
        output_root = root
    else:
        output_root = root / "dist" / args.profile

    threshold_bytes = max(1, args.auto_threshold_kib) * 1024

    print(f"[N3Z Shield v3] profile={args.profile}")
    if args.profile == "auto":
        print(f"[N3Z Shield v3] auto-threshold={args.auto_threshold_kib} KiB")
    print(f"[N3Z Shield v3] source={root}")
    if args.source_ref:
        print(f"[N3Z Shield v3] source-ref={args.source_ref}")
    print(f"[N3Z Shield v3] output={output_root}")

    total_in = total_out = count = 0
    manifest_files = []
    profile_counts = {"performance": 0, "max": 0}
    for source_path in iter_targets(root):
        relative = source_path.relative_to(root)
        output_path = output_root / relative
        original, protected, selected_profile = protect_file(
            source_path,
            output_path,
            args.profile,
            root,
            args.source_ref,
            threshold_bytes,
        )
        total_in += original
        total_out += protected
        count += 1
        profile_counts[selected_profile] += 1
        manifest_files.append(
            {
                "path": relative.as_posix(),
                "profile": selected_profile,
                "input_bytes": original,
                "output_bytes": protected,
            }
        )
        print(
            f"  [+] {relative} [{selected_profile}]: "
            f"{original} -> {protected} bytes"
        )

    if output_root != root:
        readme = root / "README.md"
        if readme.exists():
            shutil.copy2(readme, output_root / "README.md")

    manifest = {
        "shield_version": "3.0",
        "requested_profile": args.profile,
        "source_ref": args.source_ref,
        "auto_threshold_kib": args.auto_threshold_kib if args.profile == "auto" else None,
        "profile_counts": profile_counts,
        "files": manifest_files,
    }
    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "shield-manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )

    ratio = total_out / max(1, total_in)
    print(
        f"[OK] Protected {count} files "
        f"(max={profile_counts['max']}, performance={profile_counts['performance']}), "
        f"aggregate output ratio {ratio:.2f}x"
    )


if __name__ == "__main__":
    main()
