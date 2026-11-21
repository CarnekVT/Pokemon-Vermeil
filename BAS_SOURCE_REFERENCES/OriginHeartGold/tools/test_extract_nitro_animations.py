"""Synthetic, ROM-free regression tests for the private Nitro archive extractor."""
from __future__ import annotations
import importlib.util
import struct
import tempfile
from pathlib import Path
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("nitro_extractor",HERE/"extract_nitro_animations.py")
mod=importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)


def narc(*members):
    fat=struct.pack("<HH",len(members),0)
    image=b""
    for member in members:
        start=len(image)
        image+=member
        fat+=struct.pack("<II",start,len(image))
    chunks=[b"BTAF"+struct.pack("<I",len(fat)+8)+fat,
        b"BTNF"+struct.pack("<I",8),
        b"GMIF"+struct.pack("<I",len(image)+8)+image]
    length=16+sum(map(len,chunks))
    return struct.pack("<4sHHIHH",b"NARC",0xfffe,0x100,length,16,len(chunks))+b"".join(chunks)


def synthetic_rom(archive):
    # Root -> a -> 0 -> 1 -> a/0/1/0
    labels=[(b"a",0xf001),(b"0",0xf002),(b"1",0xf003)]
    tables=[bytes([0x80|len(name)])+name+struct.pack("<H",sub)+b"\0" for name,sub in labels]
    tables.append(b"\x010\0")
    cursor=32
    directory=b""
    for i,blob in enumerate(tables):
        directory+=struct.pack("<IHH",cursor,0,4 if i==0 else 0xf000+i-1)
        cursor+=len(blob)
    fnt=directory+b"".join(tables)
    rom=bytearray(0x400+len(archive))
    struct.pack_into("<IIII",rom,0x40,0x200,len(fnt),0x300,8)
    rom[0x200:0x200+len(fnt)]=fnt
    struct.pack_into("<II",rom,0x300,0x400,0x400+len(archive))
    rom[0x400:]=archive
    return bytes(rom)


class TestNitroExtractor(unittest.TestCase):
    def test_narc(self):
        self.assertEqual(mod.narc_members(narc(b"AAA",b"BBB")),[b"AAA",b"BBB"])

    def test_lz_literals(self):
        for kind in (0x10,0x11):
            src=bytes([kind,3,0,0,0])+b"ABC"
            data,mode=mod.decompress_nitro(src)
            self.assertEqual(data,b"ABC")
            self.assertIn(mode,("lz10","lz11"))

    def test_fnt_fat(self):
        a=narc(b"SUB_ANIM")
        files=mod.nds_files(synthetic_rom(a))
        self.assertEqual(files["a/0/1/0"],a)

    def test_end_to_end(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            rom=folder/"sample.nds"
            rom.write_bytes(synthetic_rom(narc(b"first",b"second")))
            result=mod.extract(rom,folder/"out")
            self.assertEqual(result["archives"]["move_anim"]["nonempty"],2)
            self.assertEqual((folder/"out"/"move_anim"/"0000.bin").read_bytes(),b"first")
            self.assertIn("a/0/2/9",result["missing_archives"])
            self.assertTrue((folder/"out"/"manifest.json").is_file())


if __name__=="__main__":
    unittest.main()
