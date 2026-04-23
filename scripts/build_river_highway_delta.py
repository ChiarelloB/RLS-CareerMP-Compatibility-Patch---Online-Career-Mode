from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path
from typing import Any


COMMON_BEAMNG_ROOTS = (
    Path("C:/Program Files (x86)/Steam/steamapps/common/BeamNG.drive"),
    Path("C:/Program Files/Steam/steamapps/common/BeamNG.drive"),
    Path("D:/SteamLibrary/steamapps/common/BeamNG.drive"),
    Path("E:/SteamLibrary/steamapps/common/BeamNG.drive"),
)


WEST_COAST_TOKENS = ("west_coast_usa", "/wca_", "wcusa")


def sha256sum(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def normalize_zip_path(path: str) -> str:
    return path.replace("\\", "/")


def read_manifest(repo_root: Path) -> dict[str, Any]:
    manifest_path = repo_root / "manifests" / "river_highway_delta_manifest.json"
    with manifest_path.open("r", encoding="utf-8") as f:
        return json.load(f)


def find_beamng_root(provided_root: Path | None) -> Path:
    if provided_root:
        root = provided_root.expanduser().resolve()
        if (root / "content").is_dir():
            return root
        raise SystemExit(f"BeamNG root does not contain a content folder: {root}")

    for root in COMMON_BEAMNG_ROOTS:
        if (root / "content").is_dir():
            return root.resolve()

    raise SystemExit(
        "BeamNG root not found. Re-run with --beamng-root pointing to your BeamNG.drive install folder."
    )


def index_beamng_archives(beamng_root: Path) -> dict[str, Path]:
    archives: dict[str, Path] = {}
    for archive in (beamng_root / "content").rglob("*.zip"):
        archives.setdefault(archive.name, archive)
    return archives


def read_zip_file(zip_path: Path, member: str) -> bytes:
    member = normalize_zip_path(member)
    with zipfile.ZipFile(zip_path, "r") as zf:
        try:
            return zf.read(member)
        except KeyError as exc:
            raise SystemExit(f"Missing required file in {zip_path.name}: {member}") from exc


def copy_overlay_files(entries: dict[str, bytes], overlay_root: Path) -> None:
    for file_path in overlay_root.rglob("*"):
        if file_path.is_dir():
            continue
        rel = file_path.relative_to(overlay_root).as_posix()
        entries[rel] = file_path.read_bytes()


def make_link_file(link_path: str) -> bytes:
    data = {"path": link_path, "type": "normal"}
    return (json.dumps(data, indent=2) + "\n").encode("utf-8")


def should_disable_shape(shape_name: str, tokens: tuple[str, ...] = WEST_COAST_TOKENS) -> bool:
    normalized = shape_name.replace("\\", "/").lower()
    return any(token in normalized for token in tokens)


def disable_west_coast_tsstatics(raw: bytes) -> bytes:
    text = raw.decode("utf-8-sig", errors="replace")
    output_lines: list[str] = []

    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            output_lines.append(line)
            continue

        try:
            item = json.loads(stripped)
        except json.JSONDecodeError:
            output_lines.append(line)
            continue

        shape_name = str(item.get("shapeName", ""))
        if item.get("class") == "TSStatic" and shape_name and should_disable_shape(shape_name):
            item["isRenderEnabled"] = False

        output_lines.append(json.dumps(item, separators=(",", ":")))

    return ("\n".join(output_lines) + "\n").encode("utf-8")


def add_beamng_entry(
    entries: dict[str, bytes],
    archive_index: dict[str, Path],
    archive_name: str,
    source_path: str,
    target_path: str,
) -> None:
    archive = archive_index.get(archive_name)
    if not archive:
        raise SystemExit(f"BeamNG content archive not found: {archive_name}")
    entries[normalize_zip_path(target_path)] = read_zip_file(archive, source_path)


def validate_entries(entries: dict[str, bytes], manifest: dict[str, Any]) -> None:
    for prefix in manifest["validation"]["forbid_prefixes"]:
        offenders = [name for name in entries if name.startswith(prefix)]
        if offenders:
            raise SystemExit(f"Forbidden legacy files found in output: {offenders[:5]}")

    for required in manifest["validation"]["required_files"]:
        if required not in entries:
            raise SystemExit(f"Required River compatibility file missing: {required}")

    for blank_file in manifest["blank_files"]:
        if entries.get(blank_file) != b"":
            raise SystemExit(f"Expected blank cleanup file is not blank: {blank_file}")

    tokens = tuple(manifest["validation"].get("west_coast_shape_tokens", WEST_COAST_TOKENS))
    for path in manifest["transform_disable_west_coast_items"]:
        raw = entries.get(path)
        if raw is None:
            raise SystemExit(f"Transformed River item file missing: {path}")
        for line in raw.decode("utf-8", errors="replace").splitlines():
            stripped = line.strip()
            if not stripped:
                continue
            try:
                item = json.loads(stripped)
            except json.JSONDecodeError:
                continue
            shape_name = str(item.get("shapeName", ""))
            if item.get("class") == "TSStatic" and should_disable_shape(shape_name, tokens):
                if item.get("isRenderEnabled") is not False:
                    raise SystemExit(f"West Coast TSStatic still render-enabled in {path}: {shape_name}")


def write_zip(zip_path: Path, entries: dict[str, bytes]) -> None:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for name in sorted(entries):
            zf.writestr(name, entries[name])


def build_river_delta(
    repo_root: Path,
    rls_river_zip: Path,
    river_phi_zip: Path,
    beamng_root: Path,
    out_dir: Path,
) -> tuple[Path, int, str]:
    manifest = read_manifest(repo_root)
    archive_index = index_beamng_archives(beamng_root)
    entries: dict[str, bytes] = {}

    for path in manifest["copy_from_rls_river"]:
        entries[path] = read_zip_file(rls_river_zip, path)

    for path in manifest["copy_from_phi"]:
        entries[path] = read_zip_file(river_phi_zip, path)

    for item in manifest["copy_from_beamng"]:
        add_beamng_entry(entries, archive_index, item["archive"], item["source"], item["target"])

    for item in manifest["aliases"]:
        source = item["source"]
        target = item["target"]
        if source == "rls_river":
            entries[target] = read_zip_file(rls_river_zip, item["source_path"])
        elif source == "phi":
            entries[target] = read_zip_file(river_phi_zip, item["source_path"])
        elif source == "beamng":
            add_beamng_entry(entries, archive_index, item["archive"], item["source_path"], target)
        else:
            raise SystemExit(f"Unknown manifest alias source: {source}")

    for path in manifest["transform_disable_west_coast_items"]:
        entries[path] = disable_west_coast_tsstatics(read_zip_file(rls_river_zip, path))

    for path in manifest["blank_files"]:
        entries[path] = b""

    for item in manifest["link_aliases"]:
        entries[item["target"] + ".link"] = make_link_file(item["link_path"])

    copy_overlay_files(entries, repo_root / "patches" / "RiverHighway" / "overlay")
    validate_entries(entries, manifest)

    output_zip = out_dir / manifest["output_name"]
    write_zip(output_zip, entries)
    return output_zip, output_zip.stat().st_size, sha256sum(output_zip)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Build the RLS CareerMP River Highway compatibility delta zip.")
    parser.add_argument("--rls-river-original", required=True, type=Path, help="Path to rls_career_overhaul_river_highway_beta_0.0.5.zip")
    parser.add_argument("--river-phi-original", required=True, type=Path, help="Path to River_Highway_Rework_PHI.zip")
    parser.add_argument("--beamng-root", type=Path, help="Path to the BeamNG.drive installation folder")
    parser.add_argument("--out-dir", type=Path, default=repo_root / "built", help="Output directory for the generated River delta zip")
    args = parser.parse_args()

    rls_river_zip = args.rls_river_original.expanduser().resolve()
    river_phi_zip = args.river_phi_original.expanduser().resolve()
    out_dir = args.out_dir.expanduser().resolve()
    beamng_root = find_beamng_root(args.beamng_root)

    if not rls_river_zip.is_file():
        raise SystemExit(f"RLS River original zip not found: {rls_river_zip}")
    if not river_phi_zip.is_file():
        raise SystemExit(f"River Highway PHI original zip not found: {river_phi_zip}")

    out_dir.mkdir(parents=True, exist_ok=True)

    output_zip, size, digest = build_river_delta(repo_root, rls_river_zip, river_phi_zip, beamng_root, out_dir)

    checksums = out_dir / "river_highway_checksums.txt"
    checksums.write_text(
        "\n".join(
            [
                f"{digest}  {output_zip.name}",
                "",
                f"{output_zip.name} size={size}",
                f"beamng_root={beamng_root}",
            ]
        ),
        encoding="utf-8",
    )

    print(f"Built: {output_zip}")
    print(f"Wrote: {checksums}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
