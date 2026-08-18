V25 NATIVE ACCELERATOR - PHASE 1
================================

This Visual 2.5D build works on both runtimes:

1) Normal / older mkxp-z:
   - V25 API is not detected.
   - The plugin automatically uses the existing Ruby projection.

2) mkxp-z-v25 Phase 1:
   - The renderer synchronizes one native pinhole camera per frame.
   - Perspective projection runs in C++.
   - NDS volume and 2.5D Geometry faces batch 4 vertices per native call.

DEBUG / A-B TEST
----------------
Open Debug and use:
  V25 Native Accelerator: ON/OFF

Use the same map and movement path with ON and OFF to compare FPS/frame time.
The existing "Estado MKXP-Z EXT / 2.5D" entry also reports V25 Native status.

EXPECTED STATUS
---------------
With the new runtime:
  V25 Native: ON

With Game - Wea Luka.exe (c6b6180) or the current stock Base Sky Game.exe (2.4.2/349d3813):
  V25 Native: UNAVAILABLE

That fallback is intentional and should not crash the project.


BASE DE SKY COMPATIBILITY REFRESH — 2026-08-17
The supplied current Windows Base de Sky runtime reports 2.4.2/349d3813. Binary comparison against the previously supplied 2.4.2/3a80c929 shows no changes in executable code; only build/version metadata differs. No Phase 1 code changes are required.
