# JSON Compatibility — early boot plugin

Standalone compatibility patch for Pokémon Essentials 21.1 and La Base de Sky 1.2.1.1.
MakerStudio versions whose 001_DataStore.rb calls `require "json"` at startup may
fail in builds with an incomplete or mismatched Ruby standard library.

This plugin is marked `First = true` with high priority, so it runs before MakerStudio.
It attempts to load native JSON; if unavailable, supplies a pure-Ruby implementation.
The `json.rb` loaded-feature marker lets **unchanged older MakerStudio releases**
continue to call `require "json"` normally. Covers JSON.parse, generate,
pretty_generate, load, dump, parse_file, load_file and parse!.

No changes to Data, MakerStudio's core, or any MakerStudio mod are necessary.
If a previously compiled PluginScripts.rxdata was not refreshed, launch the
game in Debug and force a plugin recompile (hold Ctrl on startup).

This compatibility layer handles the JSON API needed for basic MakerStudio
configuration/storage. It is not a complete replacement for the standard Ruby
JSON gem's advanced extensions.

## 1.1.0 — fileutils / Battle Scene Studio

Early startup also supplies `FileUtils.mkdir_p` (and its `mkpath` alias)
when the embedded Ruby interpreter cannot `require "fileutils"`.
The shim registers `fileutils.rb` in `$LOADED_FEATURES`, so unchanged
plugins such as Battle Scene Studio Runtime (001_Core_Utilities.rb:411) can
still `require 'fileutils'` and create the required status directory.

The native Ruby implementation remains preferred whenever it is available.
This fallback implements directory creation only, not the whole FileUtils API.
It deliberately does not modify `Data`, Essentials scripts, MakerStudio core,
or any MakerStudio mod.
