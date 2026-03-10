---
name: excalidraw
description: Create and edit Excalidraw drawings in Obsidian. Use when the user asks to draw, diagram, visualize, sketch, or work with .excalidraw files.
---

# Excalidraw Drawing Skill

You create and edit Excalidraw drawings by reading and writing `.excalidraw.md` JSON files directly. The user views them in Obsidian with the Excalidraw plugin.

## How It Works

- **Read**: `Read` the `.excalidraw.md` file, parse the JSON from the ` ```json ` block
- **Write**: Build valid Excalidraw JSON, wrap it in the file template, `Write` the file
- No MCP server, no compression, no external tools — just JSON

## File Template

Every `.excalidraw.md` file MUST follow this exact structure:

```
---

excalidraw-plugin: parsed
tags: [excalidraw]

---
==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠== You can decompress Drawing data with the command palette: 'Decompress current Excalidraw file'. For more info check in plugin settings under 'Saving'


# Excalidraw Data

## Text Elements
%%
## Drawing
` ` `json
<EXCALIDRAW JSON HERE>
` ` `
%%
```

## Excalidraw JSON Structure

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/tag/2.20.5",
  "elements": [],
  "appState": { ... },
  "files": {}
}
```

## Element Format

Every element needs these fields:
```json
{
  "id": "unique-descriptive-id",
  "type": "rectangle",
  "x": 0,
  "y": 0,
  "width": 200,
  "height": 100,
  "angle": 0,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a0",
  "roundness": null,
  "seed": 100001,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1773162000000,
  "link": null,
  "locked": false
}
```

**Element types**: `rectangle`, `ellipse`, `diamond`, `line`, `arrow`, `text`, `freedraw`

### IDs
Use descriptive strings: `"house-body"`, `"db-server"`, `"flow-step-1"`

### Index (z-order)
Fractional indexing: `a0, a1, ..., a9, aA, aB, ...`. Lower = further back.
Array order in `elements` = z-order. Put backgrounds FIRST.

### Seeds
Use unique integers. Increment from a base (e.g. 100001, 100002, ...). Seeds control the hand-drawn randomization pattern.

### Lines and Arrows
Need additional `points` field — array of `[dx, dy]` offsets from element `x,y`:
```json
{
  "type": "line",
  "x": 0, "y": 0,
  "points": [[0, 0], [100, -80], [200, 0]],
  "lastCommittedPoint": [200, 0]
}
```

Arrow-specific: `"endArrowhead": "arrow"` (or `null`, `"bar"`, `"dot"`, `"triangle"`)

### Arrow Bindings
Connect arrows to shapes:
```json
"startBinding": {"elementId": "shape-id", "fixedPoint": [1, 0.5]}
```
Fixed points: top=`[0.5,0]`, bottom=`[0.5,1]`, left=`[0,0.5]`, right=`[1,0.5]`

### Labels
On shapes (auto-centered):
```json
{"type": "rectangle", "label": {"text": "Hello", "fontSize": 20}, ...}
```
On arrows: `"label": {"text": "connects"}`

### Standalone Text
```json
{"type": "text", "x": 100, "y": 100, "text": "Title", "fontSize": 24}
```

### Rounded Corners
Add `"roundness": {"type": 3}` to rectangles.

## Color Palette

### Stroke & Primary
| Color | Hex |
|-------|-----|
| Black (default) | `#1e1e1e` |
| Blue | `#4a9eed` |
| Red | `#e03131` / `#ef4444` |
| Green | `#2f9e44` / `#22c55e` |
| Amber | `#f59e0b` |
| Purple | `#8b5cf6` |
| Pink | `#ec4899` |
| Cyan | `#06b6d4` |

### Pastel Fills (backgrounds)
| Color | Hex | Use |
|-------|-----|-----|
| Light Blue | `#a5d8ff` | Input, primary |
| Light Green | `#b2f2bb` | Success, output |
| Light Orange | `#ffd8a8` | Warning, external |
| Light Purple | `#d0bfff` | Processing, special |
| Light Red | `#ffc9c9` | Error, critical |
| Light Yellow | `#fff3bf` | Notes, decisions |
| Light Teal | `#c3fae8` | Storage, data |
| Light Pink | `#eebefa` | Analytics |

### Zone Backgrounds (use opacity: 30-60)
`#dbe4ff` (blue), `#e5dbff` (purple), `#d3f9d8` (green)

## appState Template

Use this for every drawing, adjust `scrollX`/`scrollY`/`zoom` to frame the content:

```json
"appState": {
  "theme": "dark",
  "viewBackgroundColor": "#ffffff",
  "currentItemStrokeColor": "#1e1e1e",
  "currentItemBackgroundColor": "transparent",
  "currentItemFillStyle": "solid",
  "currentItemStrokeWidth": 2,
  "currentItemStrokeStyle": "solid",
  "currentItemRoughness": 1,
  "currentItemOpacity": 100,
  "currentItemFontFamily": 5,
  "currentItemFontSize": 20,
  "currentItemTextAlign": "left",
  "currentItemStartArrowhead": null,
  "currentItemEndArrowhead": "arrow",
  "currentItemArrowType": "round",
  "currentItemFrameRole": null,
  "scrollX": 600,
  "scrollY": 500,
  "zoom": { "value": 1 },
  "currentItemRoundness": "round",
  "gridSize": 20,
  "gridStep": 5,
  "gridModeEnabled": false,
  "gridColor": {
    "Bold": "rgba(217, 217, 217, 0.5)",
    "Regular": "rgba(230, 230, 230, 0.5)"
  },
  "currentStrokeOptions": null,
  "frameRendering": {
    "enabled": true, "clip": true, "name": true,
    "outline": true, "markerName": true, "markerEnabled": true
  },
  "objectsSnapModeEnabled": false,
  "activeTool": {
    "type": "selection", "customType": null,
    "locked": false, "fromSelection": false, "lastActiveTool": null
  },
  "disableContextMenu": false
}
```

**Viewport framing**: The visible top-left is at `(-scrollX, -scrollY)`. To center content around `(cx, cy)`, set `scrollX ≈ viewportWidth/2 - cx` and `scrollY ≈ viewportHeight/2 - cy`. For wide scenes, reduce `zoom.value` (e.g. 0.75).

## Rules

1. **Do NOT use emoji** in text elements — they won't render
2. **Min sizes**: 120x60 for labeled shapes, fontSize >= 16
3. **Gaps**: leave 20-30px between elements
4. **Text contrast**: never light gray on white. Min text on white: `#757575`
5. **Consistent colors**: pick from the palette, don't freestyle hex values
6. **Z-order**: background rects first, then shapes, then labels/arrows on top
7. **When editing existing drawings**: preserve elements you didn't change, keep Obsidian's `isDeleted: true` elements (it uses them for undo history)
8. **Dark text on colored fills**: use `#15803d` not `#22c55e`, `#2563eb` not `#4a9eed`

## Compressed Files

If a file uses ` ```compressed-json ` instead of ` ```json `, it's LZ-string compressed. You have a pure-Python decompressor available — run it via Bash. Prefer asking the user to enable decompressed saving in Obsidian Excalidraw plugin settings (under Saving).
