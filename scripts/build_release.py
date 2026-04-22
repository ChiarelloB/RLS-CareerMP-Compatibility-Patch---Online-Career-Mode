from __future__ import annotations

import argparse
import hashlib
import shutil
import zipfile
from pathlib import Path


def sha256sum(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_zip_entries(zip_path: Path) -> dict[str, bytes]:
    data: dict[str, bytes] = {}
    with zipfile.ZipFile(zip_path, "r") as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            data[info.filename.replace("\\", "/")] = zf.read(info.filename)
    return data


def overlay_directory(entries: dict[str, bytes], patch_dir: Path) -> None:
    for file_path in patch_dir.rglob("*"):
        if file_path.is_dir():
            continue
        rel = file_path.relative_to(patch_dir).as_posix()
        entries[rel] = file_path.read_bytes()


def write_zip(zip_path: Path, entries: dict[str, bytes]) -> None:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for name in sorted(entries):
            zf.writestr(name, entries[name])


def build_mod(base_zip: Path, patch_dir: Path, output_zip: Path) -> tuple[int, str]:
    entries = read_zip_entries(base_zip)
    overlay_directory(entries, patch_dir)
    write_zip(output_zip, entries)
    return output_zip.stat().st_size, sha256sum(output_zip)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent

    parser = argparse.ArgumentParser(description="Build the CareerMP-compatible RLS release zips.")
    parser.add_argument("--rls-original", required=True, type=Path, help="Path to the original rls_career_overhaul_2.6.5.1.zip")
    parser.add_argument("--careermp-original", required=True, type=Path, help="Path to the original CareerMP.zip")
    parser.add_argument("--out-dir", type=Path, default=repo_root / "built", help="Output directory for the generated zips")
    args = parser.parse_args()

    rls_original = args.rls_original.expanduser().resolve()
    careermp_original = args.careermp_original.expanduser().resolve()
    out_dir = args.out_dir.expanduser().resolve()

    if not rls_original.is_file():
        raise SystemExit(f"RLS original zip not found: {rls_original}")
    if not careermp_original.is_file():
        raise SystemExit(f"CareerMP original zip not found: {careermp_original}")

    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    rls_patch_dir = repo_root / "patches" / "RLS"
    careermp_patch_dir = repo_root / "patches" / "CareerMP"

    rls_out = out_dir / "rls_career_overhaul_2.6.5.1_careermp_compatible.zip"
    careermp_out = out_dir / "CareerMP.zip"

    rls_size, rls_hash = build_mod(rls_original, rls_patch_dir, rls_out)
    cmp_size, cmp_hash = build_mod(careermp_original, careermp_patch_dir, careermp_out)

    checksums = out_dir / "checksums.txt"
    checksums.write_text(
        "\n".join(
            [
                f"{rls_hash}  {rls_out.name}",
                f"{cmp_hash}  {careermp_out.name}",
                "",
                f"{rls_out.name} size={rls_size}",
                f"{careermp_out.name} size={cmp_size}",
            ]
        ),
        encoding="utf-8",
    )

    print(f"Built: {rls_out}")
    print(f"Built: {careermp_out}")
    print(f"Wrote: {checksums}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
