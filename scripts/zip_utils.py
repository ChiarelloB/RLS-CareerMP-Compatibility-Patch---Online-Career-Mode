from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path


ZIP_ENGINE_CHOICES = ("auto", "python", "7z")


def add_zip_engine_argument(parser) -> None:
    parser.add_argument(
        "--zip-engine",
        choices=ZIP_ENGINE_CHOICES,
        default="auto",
        help=(
            "ZIP compressor to use. 'auto' uses 7-Zip when available and "
            "falls back to Python ZIP_DEFLATED for BeamNG-compatible zips."
        ),
    )


def find_7z() -> Path | None:
    for name in ("7z", "7za", "7zr"):
        found = shutil.which(name)
        if found:
            return Path(found)

    for env_name in ("ProgramFiles", "ProgramFiles(x86)"):
        base = os.environ.get(env_name)
        if not base:
            continue
        candidate = Path(base) / "7-Zip" / "7z.exe"
        if candidate.is_file():
            return candidate
    return None


def describe_zip_engine(engine: str) -> str:
    if engine not in ZIP_ENGINE_CHOICES:
        raise ValueError(f"Unknown zip engine: {engine}")
    if engine == "python":
        return "python ZIP_DEFLATED level 9"

    seven_zip = find_7z()
    if seven_zip:
        if engine == "auto":
            return f"auto: 7z ZIP Deflate ultra ({seven_zip}), python fallback"
        return f"7z ZIP Deflate ultra ({seven_zip})"
    if engine == "7z":
        return "7z requested but not found"
    return "python ZIP_DEFLATED level 9 (7z not found)"


def normalize_zip_member(name: str) -> str:
    normalized = name.replace("\\", "/").lstrip("/")
    if not normalized or normalized == ".":
        raise ValueError("Empty ZIP member name")
    if normalized == ".." or normalized.startswith("../") or "/../" in normalized:
        raise ValueError(f"Unsafe ZIP member path: {name}")
    return normalized


def write_zip(zip_path: Path, entries: dict[str, bytes], engine: str = "auto") -> str:
    if engine not in ZIP_ENGINE_CHOICES:
        raise ValueError(f"Unknown zip engine: {engine}")

    seven_zip = find_7z() if engine in {"auto", "7z"} else None
    if seven_zip:
        try:
            return write_zip_with_7z(zip_path, entries, seven_zip)
        except RuntimeError:
            if engine == "7z":
                raise
            write_zip_with_python(zip_path, entries)
            return "python-fallback"
    if engine == "7z":
        raise RuntimeError("7-Zip was requested with --zip-engine 7z, but 7z/7za/7zr was not found.")

    write_zip_with_python(zip_path, entries)
    return "python"


def write_zip_with_python(zip_path: Path, entries: dict[str, bytes]) -> None:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for name in sorted(entries):
            zf.writestr(normalize_zip_member(name), entries[name])


def write_zip_with_7z(zip_path: Path, entries: dict[str, bytes], seven_zip: Path) -> str:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    stage_parent = Path(tempfile.gettempdir())
    with tempfile.TemporaryDirectory(prefix="zip-", dir=stage_parent) as tmp_name:
        tmp_zip = Path(tmp_name) / "out.zip"
        stage_dir = Path(tmp_name) / "root"
        stage_dir.mkdir()
        for name, data in entries.items():
            target = stage_dir / normalize_zip_member(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)

        cmd = [
            str(seven_zip),
            "a",
            "-tzip",
            "-mx=9",
            "-mfb=258",
            "-mpass=15",
            "-mm=Deflate",
            "-mt=on",
            str(tmp_zip),
            ".",
        ]
        result = subprocess.run(cmd, cwd=stage_dir, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(
                "7-Zip failed while writing "
                f"{zip_path}:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
            )

        with zipfile.ZipFile(tmp_zip, "r") as zf:
            bad_member = zf.testzip()
            if bad_member:
                raise RuntimeError(f"7-Zip produced a corrupt ZIP member: {bad_member}")

        if zip_path.exists():
            zip_path.unlink()
        shutil.move(str(tmp_zip), zip_path)
    return "7z"
