"""Self-contained synthetic TGA tests. No Pokemon game content is included."""
import tempfile
from pathlib import Path
import unittest

from import_ispa_textures import convert_ispa_textures, collect_tga_sources


class TestLocalTgaConversion(unittest.TestCase):
    def setUp(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("Pillow not installed")
        self.Image = Image
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / "unpacked"
        self.folder.mkdir()
        self.project = self.root / "vermeil"
        (self.project / "Graphics").mkdir(parents=True)

    def write_tga(self, name, color=(255, 20, 70, 110)):
        path = self.folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        self.Image.new("RGBA", (8, 12), color).save(path)
        return path

    def test_converts_preserves_rgba_and_ignores_local_assets_in_git(self):
        self.write_tga("texture.tga")
        output = convert_ispa_textures(self.folder, self.project, 499)
        self.assertEqual(len(output["images"]), 1)
        item = output["images"][0]
        self.assertIn("SPA_0499/texture.png", item["project_path"])
        result = self.project / item["project_path"]
        self.assertTrue(result.exists())
        with self.Image.open(result) as image:
            self.assertEqual(image.mode, "RGBA")
            self.assertEqual(image.getpixel((0,0)), (255,20,70,110))
        folder = result.parent
        self.assertIn("499=Graphics/", (folder / "bas_graphics_map_template.txt").read_text())
        self.assertIn("!.gitignore", (folder / ".gitignore").read_text())

    def test_dry_run_and_multiple_tex_no_heuristic_emitter_index(self):
        self.write_tga("a.tga")
        self.write_tga("nested/b.tga")
        output = convert_ispa_textures(self.folder, self.project, 9, dry_run=True)
        self.assertTrue(output["requires_manual_bas_pairing"])
        self.assertEqual(len(output["images"]), 2)
        self.assertFalse((self.project / "Graphics/Animations/OriginHG_local").exists())

    def test_basename_collision_is_safe(self):
        self.write_tga("one/a.tga")
        self.write_tga("two/a.tga")
        output = convert_ispa_textures(self.folder, self.project, 12)
        names = [Path(r["project_path"]).name for r in output["images"]]
        self.assertEqual(len(set(names)), 2)
        self.assertEqual(names, ["a.png", "a_2.png"])

    def test_invalid_request_refuses(self):
        self.write_tga("a.tga")
        with self.assertRaises(ValueError):
            convert_ispa_textures(self.folder,self.project,999999)
        with self.assertRaises(ValueError):
            collect_tga_sources(self.root / "does-not-exist")


if __name__ == "__main__":
    unittest.main()
