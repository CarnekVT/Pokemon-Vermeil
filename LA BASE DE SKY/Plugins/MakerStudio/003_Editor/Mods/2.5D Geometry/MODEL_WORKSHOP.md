# 2.5D Model Studio 4.1

The model editor is intentionally low-poly and quad-based so the RPG Maker/mkxp-z runtime stays cheap, but the number of faces is not limited.

## Viewport

- **Alt + LMB** or **RMB drag**: orbit camera
- **MMB drag**: pan
- **Mouse wheel**: zoom
- **F**: frame/focus model
- **Shaded/Wire**: viewport display mode

The viewport does not rebuild model topology while orbiting. It reuses the cached mesh and temporarily draws lightweight interaction shading.

## Undo / redo

- **Ctrl+Z**: Undo
- **Ctrl+Y**: Redo
- **Ctrl+Shift+Z**: Redo

Transforms, UV edits and modeling operations are grouped into meaningful undo steps rather than one entry per mouse pixel.

## Selection and transforms

- **Q**: Object mode
- **1**: Vertex mode
- **2**: Edge mode
- **3**: Face mode
- **K**: Multi-Cut
- **W**: Move
- **E**: Rotate
- **R**: Scale

Use the colored X/Y/Z handles directly in the viewport. Selected faces also expose a purple **Normal** handle while moving; this is the fastest way to stretch an extrusion.

## Multi-Cut

Multi-Cut uses the exact clicked position on the quad rather than a fixed midpoint.

Modes:
- **Cross**: cuts at exact U and V
- **U line**: one precise vertical UV/topology cut
- **V line**: one precise horizontal UV/topology cut

Cut snap can be disabled or set from 0.5% to 10%.

## Face tools

- **Extrude**: creates cap + side faces; cap stays selected, then drag the Normal handle to extend/retract it
- **Inset**
- **Bevel**
- **Subdivide**: four quads
- **Cut U / Cut V**: loop-style midpoint split on selected quads
- **Duplicate**
- **Flip**
- **Delete**

## Vertex tools

Select 2+ vertices and use **Weld** to collapse them to a shared point.

## UV Workspace

Open **UV** from the top toolbar.

The right pane is the UV layout over the actual pixel texture. Each custom polygon has its own UV island. You can:
- select one or multiple islands
- drag islands
- resize from corner handles
- Fit to the selected texture area
- Rotate 90°
- Flip U
- Flip V

Textures/materials are assigned per polygon face. There is no five-direction face limit; primitive directional materials are only defaults.

## Runtime design

The runtime remains quad-oriented by design. This keeps generated geometry simple for MKXP-Z while still allowing arbitrary low-poly shapes through any number of editable quad faces.
