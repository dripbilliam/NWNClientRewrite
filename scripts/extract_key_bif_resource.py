"""Extract one named resource from an Aurora KEY/BIF pair."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def read_exact(stream, size: int) -> bytes:
    data = stream.read(size)
    if len(data) != size:
        raise ValueError(f"Unexpected end of file while reading {size} bytes")
    return data


def read_u16(stream) -> int:
    return struct.unpack("<H", read_exact(stream, 2))[0]


def read_u32(stream) -> int:
    return struct.unpack("<I", read_exact(stream, 4))[0]


def key_layout(key_path: Path) -> tuple[list[str], list[tuple[str, int, int, int]]]:
    with key_path.open("rb") as key:
        if read_exact(key, 4) != b"KEY ":
            raise ValueError(f"Not a KEY file: {key_path}")
        version = read_exact(key, 4)
        if version not in (b"V1  ", b"V1.1"):
            raise ValueError(f"Unsupported KEY version: {version!r}")

        bif_count = read_u32(key)
        resource_count = read_u32(key)
        if version == b"V1.1":
            key.seek(4, 1)
        bif_table_offset = read_u32(key)
        resource_table_offset = read_u32(key)

        key.seek(bif_table_offset)
        bif_names = []
        for _ in range(bif_count):
            read_u32(key)
            name_offset = read_u32(key)
            if version == b"V1.1":
                name_size = read_u32(key)
            else:
                name_size = read_u16(key)
                read_u16(key)
            current = key.tell()
            key.seek(name_offset)
            name = read_exact(key, name_size).split(b"\0", 1)[0].decode("ascii")
            key.seek(current)
            bif_names.append(name.replace("\\", "/").lstrip("/"))

        key.seek(resource_table_offset)
        resources = []
        for _ in range(resource_count):
            name = read_exact(key, 16).split(b"\0", 1)[0].decode("ascii").casefold()
            resource_type = read_u16(key)
            resource_id = read_u32(key)
            if version == b"V1.1":
                bif_index = read_u32(key) >> 20
            else:
                bif_index = resource_id >> 20
            resource_index = resource_id & 0xFFFFF
            resources.append((name, resource_type, bif_index, resource_index))

    return bif_names, resources


def extract_resource(key_path: Path, install_root: Path, resref: str, output_path: Path, bif_filter: str | None) -> None:
    bif_names, resources = key_layout(key_path)
    extension_types = {".tga": 3, ".dds": 2033, ".mdl": 2002, ".txi": 2022}
    resource_path = Path(resref)
    wanted = resource_path.stem.casefold()
    wanted_type = extension_types.get(resource_path.suffix.casefold())
    matches = [
        entry for entry in resources
        if entry[0] == wanted and (wanted_type is None or entry[1] == wanted_type)
    ]
    if bif_filter:
        matches = [entry for entry in matches if bif_names[entry[2]].casefold().endswith(bif_filter.casefold())]
    if not matches:
        raise ValueError(f"Resource not found in KEY: {resref}")
    if len(matches) > 1:
        candidates = ", ".join(bif_names[entry[2]] for entry in matches)
        raise ValueError(f"Resource is ambiguous; use --bif. Candidates: {candidates}")

    _, resource_type, bif_index, resource_index = matches[0]
    if bif_index >= len(bif_names):
        raise ValueError(f"KEY references missing BIF index {bif_index}")
    bif_path = install_root / Path(bif_names[bif_index])
    with bif_path.open("rb") as bif:
        if read_exact(bif, 4) != b"BIFF":
            raise ValueError(f"Not a BIF file: {bif_path}")
        bif_version = read_exact(bif, 4)
        if bif_version not in (b"V1  ", b"V1.1"):
            raise ValueError(f"Unsupported BIF version: {bif_version!r}")
        variable_count = read_u32(bif)
        fixed_count = read_u32(bif)
        if fixed_count != 0:
            raise ValueError("Fixed-size BIF resources are not supported")
        table_offset = read_u32(bif)
        if resource_index >= variable_count:
            raise ValueError(f"Resource index {resource_index} outside BIF table ({variable_count})")

        entry_size = 20 if bif_version == b"V1.1" else 16
        bif.seek(table_offset + resource_index * entry_size)
        read_u32(bif)
        if bif_version == b"V1.1":
            read_u32(bif)
        offset = read_u32(bif)
        size = read_u32(bif)
        bif_resource_type = read_u32(bif)
        if bif_resource_type != resource_type:
            raise ValueError("KEY and BIF disagree on the resource type")
        bif.seek(offset)
        payload = read_exact(bif, size)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(payload)
    print(f"Extracted {resref} ({size} bytes) from {bif_names[bif_index]} to {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("key", type=Path)
    parser.add_argument("install_root", type=Path)
    parser.add_argument("resref", help="Resource name including extension, e.g. plc_creats.tga")
    parser.add_argument("output", type=Path)
    parser.add_argument("--bif", help="Optional BIF path suffix to disambiguate duplicates")
    args = parser.parse_args()
    extract_resource(args.key, args.install_root, args.resref, args.output, args.bif)


if __name__ == "__main__":
    main()