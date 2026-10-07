# Audio Studio 0.8.0

Audio Studio 0.8 focuses on **composition and SFX creation first**. Cry Designer is intentionally hidden from the workspace while these two production areas are consolidated.

## Production layout

The interface follows the same practical philosophy used across Battle Animation Studio, Interface Editor and Scene Director Studio:

- **Left — Structure & Tools:** tracks, SFX stages, source tools, libraries and quick actions.
- **Center — Workspace & Preview:** Arrangement, Piano Roll, Mixer, Voice Takes, waveform and SFX envelope preview.
- **Right — Contextual Inspector:** only the properties relevant to the selected track, note, instrument layer or SFX stage.
- **Persistent transport:** playback, navigation and context remain available while editing.
- **Immediate preview:** edits are meant to be checked where they are made, not after export.

## Composition Studio

### Track structure

The left rail contains Melody, Harmony, Bass and Drums with note/hit count, instrument-layer count and direct Mute/Solo. Selecting a track updates the center editor and the Inspector.

Every track owns an independent **Instrument Stack**. Generators may derive musical notes from Melody, but they never copy Melody's instrument automatically.

### Arrangement and Song Navigator

A new **Song Navigator** stays above the workspace and represents the complete song. Click or drag anywhere on it to jump to that region. In Arrangement it also shows the current visible viewport.

Navigation options include:

- wheel/Shift+wheel horizontal navigation;
- Ctrl+wheel zoom;
- middle-button pan;
- −1 bar / +1 bar jumps;
- Fit;
- Follow playhead;
- persistent timeline and Piano Roll scroll positions.

### Piano Roll / Mixer / Voice Takes

- Composition uses a full-height internal workspace, so normal editing no longer requires scrolling down the whole page.
- Left and right panes can be collapsed independently or together with **Focus**.
- Piano Roll has a sticky piano keyboard, larger pitch rows, Smart/Draw/Select/Erase tools, note-length selection, optional scale lock, edge-resize and a separate velocity lane.
- Mixer controls track Volume/Pan/Mute/Solo and Master output.
- Voice Takes keeps recording/import, Voice Focus and exact placement separate from normal note editing.
- Global Ctrl+Z / Ctrl+Y history remains available.


### Import and reference workflow

- Import Standard MIDI files (`.mid`, `.midi`) and map each source track to Melody, Harmony, Bass or Drums before applying. Tempo import is optional.
- Import uncompressed MusicXML (`.musicxml`, `.xml`) for note/part data from notation tools.
- Imported performances keep Audio Studio's existing Instrument Stacks; they do not overwrite your chosen SoundFonts.
- Load WAV/MP3/OGG/FLAC/M4A as **session reference audio** to compose against. Reference audio has its own volume and timeline offset and is intentionally not included in song export.

### SoundFonts

Bundled banks:

- Pokémon DPP
- Pokémon HGSS
- Pokémon Black/White
- Pokémon Black/White 2

Modern Pokémon and other `.sf2` banks remain external imports. Each track/layer may use a different bank and preset.

## SFX Studio

SFX creation is organized as a selectable signal stack:

1. **Event** — Power, Pitch, Length, Texture and family.
2. **Tone** — pitched body and waveform.
3. **Noise** — unpitched texture.
4. **Sub** — low-frequency weight.
5. **Transient** — short attack/click layer.
6. **Envelope** — Attack, Decay and Sustain with visual curve.
7. **Filter** — tone shaping.
8. **Drive** — saturation.
9. **Crush** — digital grit.
10. **Delay** — echo/tail.
11. **Variants** — controlled pitch/volume variation pool for gameplay.

Tone, Noise, Sub, Transient, Filter, Drive, Crush and Delay can be bypassed individually. Selecting a stage in the left stack or center signal path opens only that stage's properties in the Inspector.

The center always provides immediate waveform output plus an envelope-shape preview and gameplay variant previews.

## Export

Composition renders to WAV in BGM/BGS/ME/SE. SFX can export the current sound or a numbered variant pool (`name_01.wav`, `name_02.wav`, etc.).

## Packaging

The mod bundles its four starter SoundFonts directly. There are no changelog text files and no README text file inside `soundfonts/`.
