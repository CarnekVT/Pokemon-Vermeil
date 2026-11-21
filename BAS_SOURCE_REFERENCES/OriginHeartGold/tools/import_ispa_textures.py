#!/usr/bin/env python3
"""Convert YOUR OWN Nitro Effect Maker .iSPA unpacked TGA textures to BAS PNGs.

Nitro Effect Maker can unpack a SPA to iSPA + TGA files. This tool does not
decode the SPA animation graph, invent emitter-to-texture relations, distribute
Pokemon assets, or read a ROM. It handles only files already unpacked by the user.
Example:
    python -m pip install Pillow
    python BAS_SOURCE_REFERENCES/OriginHeartGold/tools/import_ispa_textures.py \
        --input "C:/MySPA/Unpacked" --spa 499 --project "LA BASE DE SKY"
The created files are gitignored by default (copyright-sensitive local assets).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
import sys

MAX_SOURCE_BYTES = 25 * 1024 * 1024
MAX_DIMENSION = 4096
MAX_IMAGES = 256


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            h.update(block)
    return h.hexdigest()


def sanitize_stem(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_-]+", "_", name).strip("_")
    return (cleaned[:70] or "texture").lower()


def collect_tga_sources(folder: Path) -> list[Path]:
    if not folder.is_dir():
        raise ValueError("Nitro Effect Maker output folder does not exist")
    sources = sorted(
        (p for p in folder.rglob("*") if p.is_file() and p.suffix.lower() == ".tga"),
        key=lambda p: str(p.relative_to(folder)).lower(),
    )
    if not sources:
        raise ValueError("No TGA textures found. Unpack the SPA with Nitro Effect Maker first")
    if len(sources) > MAX_IMAGES:
        raise ValueError(f"Over {MAX_IMAGES} textures: refusing oversized input")
    for source in sources:
        if source.is_symlink() or any(part.is_symlink() for part in source.parents if part != folder.parent):
            raise ValueError(f"Symlink textures are not allowed: {source}")
        if source.stat().st_size > MAX_SOURCE_BYTES:
            raise ValueError(f"TGA is over {MAX_SOURCE_BYTES} bytes: {source.name}")
    return sources


def convert_ispa_textures(folder: Path, project: Path, spa: int, *, dry_run: bool = False) -> dict:
    if not (0 <= spa <= 65535):
        raise ValueError("SPA index must be between 0 and 65535")
    if not project.is_dir() or not (project / "Graphics").is_dir():
        raise ValueError("Project needs an existing Graphics folder")
    try:
        from PIL import Image
    except ImportError as e:
        raise RuntimeError("Install Pillow first: python -m pip install Pillow") from e
    Image.MAX_IMAGE_PIXELS = MAX_DIMENSION * MAX_DIMENSION
    sources = collect_tga_sources(folder)
    relative = Path("Graphics") / "Animations" / "OriginHG_local" / f"SPA_{spa:04d}"
    output_folder = project / relative
    seen: set[str] = set()
    data: list[dict] = []
    for source in sources:
        stem = sanitize_stem(source.stem)
        base = stem
        i = 2
        while stem.lower() in seen:
            stem = f"{base}_{i}"
            i += 1
        seen.add(stem.lower())
        target = output_folder / f"{stem}.png"
        with Image.open(source) as image:
            image.load()
            width, height = image.size
            if width <= 0 or height <= 0 or width > MAX_DIMENSION or height > MAX_DIMENSION:
                raise ValueError(f"TGA dimensions exceed {MAX_DIMENSION}: {source.name}")
            rgba = image.convert("RGBA")
            if not dry_run:
                output_folder.mkdir(parents=True, exist_ok=True)
                rgba.save(target, "PNG", optimize=False)
        record = {
            "source_tga": str(source.relative_to(folder)).replace("\\", "/"),
            "source_sha256": sha256(source),
            "project_path": str(relative / target.name).replace("\\", "/"),
            "width": width, "height": height,
        }
        if not dry_run:
            record["png_sha256"] = sha256(target)
        data.append(record)
    template = [
        "# Bind SPA resource IDs to verified converted textures in BAS Nitro importer.",
        "# Emitter-to-texture relationships are NOT inferred from filenames or guessed.",
        "# For multiple textures, check iSPA emitter settings before assigning an emitter index.",
        "# Format: <SPA>:<emitter>=Graphics/Animations/.../<texture>.png",
    ]
    if len(data) == 1:
        template.append(f"{spa}={data[0]['project_path']}")
    else:
        template += ["# Candidate: " + entry["project_path"] for entry in data]
    result = {
        "format": "BAS-user-local-ispa-textures-v1", "spa": spa, "images": data,
        "not_an_animation": True, "emitter_mapping_verified": False,
        "requires_manual_bas_pairing": len(data) > 1,
    }
    if not dry_run:
        output_folder.mkdir(parents=True, exist_ok=True)
        # The private output is ignored even when stored below the user's Git worktree.
        (output_folder / ".gitignore").write_text("*\n!.gitignore\n", encoding="utf-8")
        (output_folder / "bas_graphics_map_template.txt").write_text(
            "\n".join(template) + "\n", encoding="utf-8"
        )
        (output_folder / "manifest.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Nitro Effect Maker iSPA unpacked folder")
    parser.add_argument("--project", required=True, type=Path, help="Pokémon Vermeil root containing Graphics")
    parser.add_argument("--spa", required=True, type=int, help="SPA file index from addparticle/loadparticlefromspa")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        result = convert_ispa_textures(args.input, args.project, args.spa, dry_run=args.dry_run)
    except (ValueError, OSError, RuntimeError) as error:
        parser.error(str(error))
    print(json.dumps({"converted":len(result["images"]), "spa":args.spa,
                      "first":result["images"][0]["project_path"],
                      "dry_run":args.dry_run},ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
