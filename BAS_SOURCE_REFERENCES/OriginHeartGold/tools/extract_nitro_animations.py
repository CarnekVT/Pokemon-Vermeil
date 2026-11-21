#!/usr/bin/env python3
"""Extract *local user-supplied* Origin HeartGold animation source archives.

No ROM/game graphics or sounds are bundled in this repository.
This only unpacks animation/SPA files for local inspection; raw .SPA and
bytecode scripts are NOT directly importable into Battle Animation Studio.
Usage:
  python extract_nitro_animations.py --rom "my-own-origin-hg.nds" --out "./private-nitro"
The output should never be committed or redistributed without permission.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

# NDS Nitro FNT/FAT paths: US HGSS and Origin HG v4.0.3 file layout.
ARCHIVES = {
    "move_anim": ("a/0/1/0", "move-anim (wazaeffect / we.arc)"),
    "move_sub_anim": ("a/0/6/1", "auxiliary animations, verify membership per build"),
    "particle_spa": ("a/0/2/9", "Nitro SPA emitter/texture resources")
}
MAX_ROM = 1024 * 1024 * 1024
MAX_MEMBER = 40 * 1024 * 1024


def u16(b: bytes, at: int) -> int:
    return struct.unpack_from("<H", b, at)[0]


def u32(b: bytes, at: int) -> int:
    return struct.unpack_from("<I", b, at)[0]


def nds_files(rom: bytes) -> dict[str, bytes]:
    if len(rom) < 0x200:
        raise ValueError("Incomplete Nintendo DS header")
    fnt_start, fnt_size = u32(rom, 0x40), u32(rom, 0x44)
    fat_start, fat_size = u32(rom, 0x48), u32(rom, 0x4c)
    if (not fnt_size or not fat_size or fnt_start+fnt_size>len(rom)
        or fat_start+fat_size>len(rom)):
        raise ValueError("Invalid Nitro FNT/FAT bounds")
    fnt = rom[fnt_start:fnt_start+fnt_size]
    fat = rom[fat_start:fat_start+fat_size]
    if len(fnt) < 8:
        raise ValueError("No FNT root record")
    n_dirs = u16(fnt, 6)
    if not 1 <= n_dirs <= 4096 or n_dirs*8>len(fnt):
        raise ValueError("Invalid Nitro directory count")
    result: dict[str, bytes] = {}
    seen: set[int] = set()

    def directory(directory_id: int, prefix: str):
        if directory_id in seen:
            raise ValueError("Recursive FNT directory")
        seen.add(directory_id)
        index = directory_id & 0xfff
        if index>=n_dirs:
            raise ValueError("FNT directory id outside table")
        subtable, file_id, _parent = struct.unpack_from("<IHH", fnt, index*8)
        cursor = subtable
        while cursor < len(fnt):
            desc = fnt[cursor]
            cursor += 1
            if not desc:
                return
            length = desc & 0x7f
            if length==0 or cursor+length>len(fnt):
                raise ValueError("Invalid FNT file name")
            name = fnt[cursor:cursor+length].decode("ascii", "replace")
            cursor += length
            if "/" in name or "\\" in name or name in (".",".."):
                raise ValueError("Unsafe FNT path")
            if desc & 0x80:
                if cursor+2>len(fnt):
                    raise ValueError("Truncated FNT subdir")
                child = u16(fnt,cursor)
                cursor += 2
                directory(child,prefix+name+"/")
            else:
                fat_index = file_id*8
                file_id += 1
                if fat_index+8>len(fat):
                    raise ValueError("FAT file index outside table")
                offset,end=struct.unpack_from("<II",fat,fat_index)
                if end<offset or end>len(rom):
                    raise ValueError("Invalid FAT file span")
                result[prefix+name]=rom[offset:end]
        raise ValueError("Unterminated FNT directory")
    directory(0xf000,"")
    return result


def decompress_nitro(data: bytes) -> tuple[bytes, str]:
    if not data or data[0] not in (0x10,0x11) or len(data)<4:
        return data,"none"
    form=data[0]
    length = int.from_bytes(data[1:4],"little")
    pos=4
    if length==0:
        if len(data)<8: raise ValueError("Truncated extended LZ header")
        length=u32(data,4)
        pos=8
    if length>MAX_MEMBER:
        raise ValueError("Refusing overlarge Nitro LZ stream")
    out=bytearray()
    while len(out)<length:
        if pos>=len(data):raise ValueError("Truncated Nitro LZ flags")
        flags=data[pos]
        pos+=1
        for bit in range(7,-1,-1):
            if len(out)>=length:break
            if not flags&(1<<bit):
                if pos>=len(data):raise ValueError("Truncated Nitro LZ literal")
                out.append(data[pos]);pos+=1
                continue
            if pos+2>len(data):raise ValueError("Truncated Nitro LZ reference")
            a,b=data[pos:pos+2]
            pos+=2
            if form==0x10:
                length_copy=(a>>4)+3
                displacement=((a&15)<<8)|b
            else:
                top=a>>4
                if top==0:
                    if pos>=len(data):raise ValueError("Truncated LZ11 long match")
                    d=data[pos];pos+=1
                    length_copy=((a&15)<<4)+(b>>4)+0x11
                    displacement=((b&15)<<8)|d
                elif top==1:
                    if pos+2>len(data):raise ValueError("Truncated LZ11 extra-long match")
                    d,e=data[pos:pos+2];pos+=2
                    length_copy=((a&15)<<12)+(b<<4)+(d>>4)+0x111
                    displacement=((d&15)<<8)|e
                else:
                    length_copy=top+1
                    displacement=((a&15)<<8)|b
            distance=displacement+1
            if distance>len(out):raise ValueError("Invalid LZ history displacement")
            for _ in range(min(length_copy,length-len(out))):
                out.append(out[-distance])
    return bytes(out), ("lz10" if form==0x10 else "lz11")


def narc_members(data: bytes) -> list[bytes]:
    if len(data)<16 or data[:4]!=b"NARC":
        raise ValueError("Archive is not a NARC file")
    header=u16(data,12)
    if header<16 or header>len(data):raise ValueError("Bad NARC header size")
    cursor=header
    chunks={}
    while cursor+8<=len(data):
        tag=data[cursor:cursor+4]
        size=u32(data,cursor+4)
        if size<8 or cursor+size>len(data):raise ValueError("Invalid NARC chunk")
        chunks[tag]=data[cursor+8:cursor+size]
        cursor+=size
    fat=chunks.get(b"BTAF") or chunks.get(b"FATB")
    image=chunks.get(b"GMIF") or chunks.get(b"FIMG")
    if not fat or image is None or len(fat)<4:
        raise ValueError("Incomplete NARC FAT/GMIF")
    total=u16(fat,0)
    if total>20000 or 4+8*total>len(fat):
        raise ValueError("Invalid NARC member table")
    members=[]
    for i in range(total):
        start,end=struct.unpack_from("<II",fat,4+8*i)
        if end<start or end>len(image):
            raise ValueError("Member outside NARC image")
        members.append(image[start:end])
    return members


def extract(rom_path: Path, out_dir: Path):
    if not rom_path.is_file():raise FileNotFoundError(rom_path)
    if rom_path.stat().st_size>MAX_ROM:raise ValueError("ROM unexpectedly large")
    rom=rom_path.read_bytes()
    files=nds_files(rom)
    manifest={"format":"bas-local-nitro-animation-extraction-v1",
        "note":"Local inspection only. Raw DS bytecode/.SPA is not a runnable BAS animation.",
        "rom_sha256":hashlib.sha256(rom).hexdigest(),
        "archives":{}, "missing_archives":[]}
    out_dir.mkdir(parents=True,exist_ok=True)
    for kind,(path,purpose) in ARCHIVES.items():
        blob=files.get(path) or files.get("data/"+path)
        if blob is None:
            manifest["missing_archives"].append(path)
            print("MISSING archive:",path,file=sys.stderr)
            continue
        unpacked,compression=decompress_nitro(blob)
        try:members=narc_members(unpacked)
        except ValueError as exc:
            print("UNSUPPORTED archive:",path,str(exc),file=sys.stderr)
            manifest["missing_archives"].append(path+": "+str(exc))
            continue
        directory=out_dir/kind
        directory.mkdir(exist_ok=True)
        records=[]
        for i,payload in enumerate(members):
            if not payload:continue
            # Do not pretend that a raw SPA is an editable image or clip.
            extension=".spa" if kind=="particle_spa" else ".bin"
            target=directory/("%04d"%i+extension)
            target.write_bytes(payload)
            records.append({"index":i,"file":str(target.relative_to(out_dir)).replace("\\","/"),
                "bytes":len(payload),"sha256":hashlib.sha256(payload).hexdigest()})
        manifest["archives"][kind]={"nds_path":path,"purpose":purpose,
            "compression":compression,"members":len(members),"nonempty":len(records),
            "files":records}
        print(kind,len(records),"/",len(members),"extracted")
    (out_dir/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (out_dir/".gitignore").write_text("*\n!.gitignore\n",encoding="utf-8")
    return manifest


def main():
    parser=argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--rom",required=True,type=Path,help="Your legally obtained NDS ROM file")
    parser.add_argument("--out",required=True,type=Path,help="Private output directory; never commit extracted assets")
    args=parser.parse_args()
    try:
        result=extract(args.rom,args.out)
    except (OSError,ValueError,struct.error) as exc:
        parser.exit(1,"Extraction failed: "+str(exc)+"\n")
    if not result["archives"]:
        parser.exit(2,"No compatible animation NARCs were found in this ROM.\n")


if __name__=="__main__":
    main()
