# Frigorify

A small Typst library for dilution refrigerator wiring diagrams, built with [CeTZ](https://cetz-package.github.io/docs/). Stage boundaries are vertical and signal lines are horizontal, following the supplied Inkscape example.

> [!WARNING]
> This project is a vibe coding project and there might be some bugs to iron out. Don't hesitate to leave an issue with a screen shot and code for any bugs you might encounter.

## Quick start

From this repository:

```typst
#import "src/frigorify.typ": fridge
#fridge(json("examples/fridge.json"))
```

For a native Typst dictionary and drawing-block commands, see [examples/block.typ](examples/block.typ). The package entrypoint in `typst.toml` is ready for local package installation, but this library is not published on Typst Universe.

Compile the examples from the repository root (Typst needs `--root .` for their imports):

```sh
typst compile --root . examples/basic.typ examples/basic.pdf
typst compile --root . examples/block.typ examples/native.pdf
typst compile --root . tests/layout.typ /tmp/frigorify-layout.pdf
python3 tests/check.py
```

Requires CeTZ 0.5.2; Typst downloads it on first use if it is not cached.

## JSON configuration

```json
{
  "stages": [
    {"id": "4k", "label": "4 K"},
    {"id": "mix", "label": "10 mK"}
  ],
  "lines": [
    {
      "label": "Drive",
      "port": "9",
      "components": [
        {"type": "attenuator", "stage": "4k", "db": 20},
        {"type": "attenuator", "stage": "mix", "db": 3},
        {"type": "filter", "stage": "mix", "kind": "LPF"}
      ]
    }
  ]
}
```

- `stages` is a nonempty ordered array. Each stage has a unique string `id` and a string `label`. Stages appear left to right in array order.
- `lines` is a nonempty ordered array, drawn top to bottom. `label` defaults to the line number; `port` optionally labels the right endpoint; omit it or use JSON `null` / Typst `none` to draw no port label. `color` optionally supplies a hex string such as `"#345c9c"`.
- `components` is optional on each line. Each component needs a `type` and a `stage` referring to an existing stage ID.

**Placement convention:** the first component touches the right side of its named stage boundary. Further components at that stage follow it in a chain. This indicates the stage where it is mounted. Components at the same stage are drawn in their array order; stage order determines their positions across the diagram. Components on the last stage occupy an automatically sized interval before the right endpoint. Array order and stage assignment describe physical placement; `direction` controls the symbol's arrow/orientation.

| Type | Symbol | Optional fields |
| --- | --- | --- |
| `attenuator` | Rectangle with attenuation | `db` (defaults to 0), `label`, `padding-x`, `padding-y` |
| `amplifier` | Equilateral triangle | `gain` (string), `direction` (`left` by default or `right`), `label` |
| `circulator` | One or two circles with open curved arrows | `direction` (`right` for counterclockwise, `left` for clockwise), `junctions` (1 or 2), `label` |
| `short` | Short to ground, ends the line | `direction` (default `down`) |
| `load` | 50 Ω resistor to ground, ends the line | `direction` (default `down`) |
| `rf-switch` | Circle with one center and six outer ports | `label`, `width` |
| `filter` | Pass-response symbol in a rectangle | `kind` (`LPF`, `HPF`, `BPF`, or their spelled-out names), `label` |

`label` overrides any generated component label. `width` optionally sets a minimum width in canvas units; measured label width still takes precedence. Extra configuration fields are ignored, allowing future metadata. JSON is only data: the library does not evaluate code in labels.

Circulators have inline left/right ports and bottom ports for custom routing. Probe enclosures are not yet implemented.

## Layout and styling

```typst
#fridge(json("examples/fridge.json"),
  unit: 1cm,
  font-size: 9pt,
  min-stage-gap: 1.6,
  component-gap: 0.18,
  stage-padding: 0.22,
  attenuator-padding-x: 0.12,
  attenuator-padding-y: 0.08,
  line-gap: 0.85,
  stroke: 0.7pt,
  stage-stroke: 1.2pt,
  lead: 0.65,
)
```

Numeric distances are in `unit` (1 cm by default). `line-gap` controls the vertical distance between signal lines; retain enough room for labels above amplifiers and circulators when changing it or the font size. `lead` controls wire length outside the first and last intervals. `stroke` is a stroke thickness; stage boundaries have a separate thickness.

`attenuator-padding-x` and `attenuator-padding-y` set the minimum space on each side of attenuator text, in canvas units. They also work in `style`. Override them per attenuator using `padding-x` and `padding-y`, for example `(type: "attenuator", stage: "4k", db: 20, padding-x: 0.3, padding-y: 0.15)` or `add.attenuator("drive", "4k", db: 20, padding-x: 0.3)`. Values must be nonnegative. Boxes retain a minimum width of 0.95 and height of 0.48 units, so short labels can have extra space. Larger vertical padding may require increasing `line-gap`. Standalone renderers accept `height` in the component dictionary; automatic text padding is calculated by `fridge-layout` and `fridge`.

For each interval, Frigorify measures label widths and sums component widths, component gaps, and trailing stage padding for every line. The largest required width sets the interval width for all lines. Neighboring stage labels also set a lower bound on spacing. Empty intervals retain `min-stage-gap`. This produces aligned stage boundaries without manual coordinates.

`fridge-layout(config, ...)` exposes the computed `stages`, `end`, `gaps`, and per-line component `widths`, plus spacing values. It accepts the geometry and font options above, except `stroke`, `stage-stroke`, and `lead`. Call it inside `context`, because label measurements depend on Typst's text environment.

`fridge-component(component, x: 0, y: 0, width: 1, font-size: 9pt, stroke: 0.7pt)` emits a standalone symbol inside a CeTZ canvas. Its `x` is the left edge and `y` is the center of the signal line. Amplifiers have a fixed triangle height of 0.48 units, and circulators a fixed diameter of 0.54 units per junction; `width` reserves room for their labels and the next component. `stage-padding` is clearance after a component chain, before the next boundary; use `fridge-layout` when automatic text fitting is needed.

## Source organization

`src/frigorify.typ` handles configuration validation, stage spacing, and wire layout.
`src/components.typ` contains `attenuator`, `amplifier`, `circulator`, and `filter`, each with the same arguments as `fridge-component`. The main module re-exports these functions, so either module can be used to import individual symbols. `fridge-component` dispatches to the appropriate function using the configuration's `type`.

## Block API and CeTZ extensions

Use the `add` namespace to add components by wire and stage. Components are collected before drawing so that stage spacing remains automatic.

```typst
#import "src/frigorify.typ" as f
#import "@preview/cetz:0.5.2": draw

#f.fridge((
  stages: ((id: "4k", label: "4 K"), (id: "mix", label: "10 mK")),
  lines: ((id: "drive",), (id: "output",)),
), style: (
  line-gap: 1.05,
  component-gap: 0.12,
  stage-padding: 0.22,
  stroke: 0.7pt,
), {
  import f.add: *
  attenuator("drive", "4k", db: 20)
  filter("drive", "mix", kind: "low-pass")
  amplifier("output", "4k", direction: "left", gain: "HEMT")
  circulator("output", "mix", junctions: 2, direction: "left")
  draw.content("component-2-2.north", [Double junction], anchor: "south")
})
```

See `examples/block.typ` for a complete working example. A wire selector is a string matching its `id` (or its `label` if it has no ID), or a one-based integer line number. Each selector must match exactly one line. Stage selectors use stage IDs. Additions append to any components already in the config; the original config is preserved. Components at the same stage follow call order.

`style` accepts all the diagram options shown above and overrides the individual keyword arguments. Reuse a general style with `let my-fridge = f.fridge.with(style: (line-gap: 1.05, component-gap: 0.12))`. Geometry values use canvas units; `stroke` and `stage-stroke` are thicknesses.

Ordinary CeTZ calls in the block render after the diagram, in their relative order. Named anchors are `stage-ID`, `wire-N`, and `component-N-M`, where N is the one-based line number and M is its component index in the combined config and additions. For example, `component-2-2.north` selects the top of the second component on the second line. These names can be used in CeTZ content, lines, and other drawing functions. Use `add.overlay(layout => { ... })` when your drawing needs the final numerical stage positions or line spacing; it receives the same dictionary returned by `fridge-layout`.

Double-junction circulators use `junctions: 2` (or `"junctions": 2` in JSON). Their circles touch and share a rectangle with zero padding; layout reserves room for both junctions. Single junctions remain the default. LPF, HPF, and BPF filters now show response symbols instead of acronyms; an explicit `label` appears above those symbols. Other kinds, such as RC, keep their text labels for compatibility.

Low-level functions in `components.typ` still draw individual symbols inside CeTZ canvases. `builders.typ` contains the block commands and config assembly, while `frigorify.typ` handles validation and layout.

## API reference

Public functions and their parameters use [Tidy 0.4.3](https://typst.app/universe/package/tidy/) doc-comments (`///` descriptions and `->` type annotations) directly in the source. The reference covers diagram/layout functions, standalone CeTZ symbols, and `add` drawing-block commands, including defaults, units, and component options.

Generate the reference from the repository root:

```sh
typst compile --root . docs/reference.typ docs/reference.pdf
```

Tidy is needed only to build the documentation, not to use Frigorify.

## RF switches

Use `add.rf-switch(wire, stage)` or a component dictionary with `type: "rf-switch"`.
The circle contains seven small ports: a common center and six outer ports.
The selected wire enters from the left and ends at the common port. A switch
must be the final component along that wire; its usual right-end `port` label
is omitted. Other wires continue normally.

Connect outputs with ordinary CeTZ lines in the drawing block:

```typst
f.add.rf-switch("drive", "mix")
draw.line("component-1-1.port-2", (3, 0.14), (3, 0.6), (4, 0.6))
draw.line("component-1-1.port-3", (3.2, -0.14), (3.2, -0.6), (4, -0.6))
```

Here the switch is the first component on the first wire. Adjust `component-N-M`
for its wire and component index. The `common` anchor is the center;
`port-1` through `port-6` run clockwise from the top, so ports 2 and 3 face right.
The standalone `rf-switch` renderer exposes the same anchors when wrapped in a
named CeTZ group. The symbol has diameter 0.8 canvas units; increase `line-gap`
when needed for output routing. See `examples/block.typ` for a complete example.

## Routed connections: sline and zline

Import `sline` and `zline` from the main module, or use `add.sline` and
`add.zline` in a drawing block. They accept CeTZ coordinates (including named
RF switch ports), and forward line options such as `stroke`, `name`, and `mark`.

```typst
f.sline("component-1-2.port-2", (3.6, 0.55))
f.zline("component-1-2.port-3", (3.6, -0.55), ratio: 55%)
```

`sline` uses one right-angle bend,initially horizontal. `zline` uses
horizontal–vertical–horizontal segments, with the vertical segment halfway between
endpoint x coordinates by default. Set `axis: "y"` for vertical-first routing.
`ratio` controls the middle segment position (`50%` by default); numbers and
lengths follow CeTZ's interpolation distance convention. Routing applies to
every consecutive pair when passing more than two coordinates. Neither helper
avoids obstacles automatically.

## Circulator ports

Circulators expose anchors directly on their component group:

| Anchor | Position |
| --- | --- |
| `in` or `port-1` | Left edge of the first junction |
| `out` or `port-2` | Right edge of the last junction |
| `port-3` | Bottom of the first junction |
| `port-4` | Bottom of the second junction (only with `junctions: 2`) |
| `junction-J-port-1`, `junction-J-port-2`, `junction-J-port-3` | Left, right, bottom of junction J (one-based) |

```typst
f.add.circulator("output", "mix", junctions: 2)
f.zline("component-2-1.port-3", (4, -2), axis: "y")
f.sline("component-2-1.port-4", (5, -2.5), axis: "y")
```

Adjust the component name to its actual line and component index. Port positions
are on the circle outline and remain fixed for either arrow direction, long
labels, and custom reserved widths. The bottom ports need explicit connections;
placing a circulator still draws the usual inline line. Standalone renderers expose
the same anchors inside a named CeTZ group. See `examples/block.typ`.

Lines drawn in a `fridge` block, including `draw.line`, `sline`, `zline`, and
lines returned by `add.overlay`, inherit the diagram's `stroke` (including
`style: (stroke: ...)`). Pass an explicit `stroke` to a line to override it.
CeTZ `draw.set-style(line: (stroke: ...))` can also change the default for
subsequent lines in the block.

### Top/bottom ports and fridge line endpoints

Use `port-3-top` or `port-3-bottom` to choose the first junction's connection
side, and `port-4-top` or `port-4-bottom` for the second junction. Existing
`port-3` and `port-4` anchors still refer to the bottom. Per-junction anchors
also support `junction-J-port-3-top` and `junction-J-port-3-bottom`.

To end an existing fridge line at a circulator on another line:

```typst
f.add.circulator("output", "mix", junctions: 2)
f.add.connect("upper", to: "component-2-1.port-3-top")
f.add.connect("lower", to: "component-2-1.port-4-bottom")
```

`add.connect` accepts the usual line ID, label, or one-based number. It replaces
the line's right endpoint with a horizontal run and a vertical bend ending at
the selected port. Its color and fridge stroke are preserved; the former endpoint
label is omitted. Components on the connecting line must fit before the bend.
The target can be declared later in the block. JSON/native line dictionaries
can equivalently use `connect: "component-2-1.port-3-top"`. A line can have only
one endpoint connection and cannot also terminate at an RF switch.
See `examples/block.typ` for a complete example.

## Short and 50 Ω ground terminations

Use `add.short` for a direct short to ground, or `add.load` for a rectangular
50 Ω resistor followed by ground. Pass a fridge line ID, label, or one-based
number to terminate its right endpoint, or a named component port to attach
there instead:

```typst
f.add.short("shorted")
f.add.load("loaded")
f.add.short("component-3-1.port-3-top", direction: "up")
f.add.load("component-3-1.port-4-bottom")
```

`direction` selects where ground sits relative to the connection (`down` by
default; also `up`, `left`, or `right`). Terminations inherit the fridge stroke;
an explicit `stroke` overrides it. `load` accepts `font-size` (default 9pt).
An optional `name` exposes `name.in` and `name.ground` anchors. Line endpoint
terminations omit the former endpoint label and cannot be combined with an
endpoint connection or RF switch on that line. Ports may be declared later in
the block. Allow room between lines for resistor labels and ground symbols.

For standalone CeTZ drawing, `f.short(coordinate, ...)` and `f.load(coordinate, ...)`
accept plain points and named anchors. See `examples/block.typ`.

### Terminations in JSON

For a line endpoint, add `"termination": "short"` or `"termination": "load"`
to the line object. Use a dictionary to select direction:

```json
{"id": "loaded", "termination": {"type": "load", "direction": "down"}}
```

For component ports, add a top-level `terminations` array:

```json
"terminations": [
  {"target": "component-3-1.port-3-top", "type": "short", "direction": "up"},
  {"target": "component-3-1.port-4-bottom", "type": "load"}
]
```

Each entry requires `type` (`short` or `load`) and `target` (a named anchor,
line ID/label, or one-based line number). Optional fields include `direction`, `name`, `scale`, `label`, `show-label`,
`font-size`, and `stroke`. Symbols inherit the diagram stroke and font size. See
`examples/basic.typ` for JSON rendering and `examples/block.typ` for block commands.

### Stage-mounted termination components

To choose the mounting stage, put a termination in the line's `components` array:

```json
{
  "id": "loaded",
  "components": [
    {"type": "attenuator", "stage": "4k", "db": 20},
    {"type": "load", "stage": "mix"}
  ]
}
```

Use `{"type": "short", "stage": "4k"}` for a short. Terminations follow the
same stage-placement convention as other components; the input is offset
0.2 canvas units from the component's left edge to clear the stage boundary.
The line ends there and the former right endpoint label is omitted. A termination
must be the final component in physical stage order and cannot share its line
with an RF switch, endpoint `connect`, or endpoint `termination`.

In a drawing block, use `add.short(line, stage)` or `add.load(line, stage)`:

```typst
f.add.short("shorted", "4k")
f.add.load("loaded", "mix")
```

`direction` defaults to `down`; `up`, `left`, and `right` are supported.
These components inherit the diagram's stroke and font size and expose a
`component-N-M.in` anchor. Calls without a stage and the previous endpoint/port
JSON syntax remain supported. See `examples/fridge.json`.

### Termination size and labels

Shorts and loads default to `scale: 0.65` (65% of the original geometry).
All termination options work in JSON component objects, endpoint/port termination
objects, and `add.short` / `add.load` calls:

| Option | Default | Meaning |
| --- | --- | --- |
| `scale` | `0.65` | Positive geometry multiplier; text and stroke thickness are independent |
| `show-label` | `true` | Set to `false` to hide the label |
| `label` | `"50 Ω"` for loads, empty for shorts | Custom text; `false`, JSON `null`, or `""` hides it |
| `font-size` | Diagram font size | Text size; JSON numbers are points |
| `stroke` | Diagram stroke | Explicit thickness; JSON numbers are points |
| `direction` | `"down"` | `"up"`, `"down"`, `"left"`, or `"right"` |

```json
{"type": "load", "stage": "mix", "scale": 0.5, "show-label": false}
```

```typst
f.add.load("loaded", "mix", scale: 0.5, show-label: false)
f.add.load("component-3-1.port-4-bottom", scale: 0.5, label: "Matched", font-size: 7pt)
```

Setting `scale: 1` restores the original symbol size. Stage layout measures only
visible labels, using their configured font size.

## Components left of the first stage

Set `first-stage-side: "left"` to place the first stage's component chains
before its boundary. Later stages keep their usual placement. Components
retain their left-to-right array/call order; each first-stage chain ends at
the boundary. Incoming leads and line labels move left automatically to clear
the longest chain, and the first stage's right interval no longer reserves
space for those components.

```typst
f.fridge(config, first-stage-side: "left")
// Or: f.fridge(config, style: (first-stage-side: "left"))
```

In JSON, set the top-level field `"first-stage-side": "left"`. It defaults
to `"right"`; an explicit function argument overrides JSON, and `style`
overrides the function argument. Components added through the block API follow
the same rule. See `examples/fridge.json`.

`fridge-layout` accepts the same option and returns `component-starts` (nested
per-line/per-stage chain x positions), `left-extent` (space before stage zero),
and the resolved `first-stage-side`. Named component ports, connections, and
stage terminations use these positions automatically. Stage zero remains at x=0.

The complete configuration and API guide is in `docs/guide.typ`, included by
`docs/reference.typ`. See `docs/README.md` for documentation build instructions.

Amplifiers reserve their actual triangle width (about 0.416 canvas units) by
default. Labels or explicit minimum `width` can enlarge this reservation.
`component-gap` is added after the reservation; `min-stage-gap` and stage
label fitting can still leave extra space before the next stage boundary.

## Directional couplers

Amplifiers default to `direction: "left"`; set `"right"` explicitly when needed.

Use `add.directional-coupler(through, coupled, stage)` to place a three-port
coupler between adjacent lines, matching the straight/curved-path symbol in the
reference setup. The through line continues; the coupled line ends at the input.
Couplers follow block call order within each stage. Layout reserves
space automatically, including first-stage-left placement.

```typst
f.add.directional-coupler("main", "coupled", "mix", name: "dc")
```

```json
"couplers": [
  {"through": "main", "coupled": "coupled", "stage": "mix", "name": "dc"}
]
```

Selectors accept line IDs, labels, or one-based numbers. Optional `width` defaults
to 0.9, `label` defaults to empty, and `name` defaults to `coupler-N` (one-based).
Use unique names. Anchors are `dc.main-in`, `dc.main-out`, and `dc.coupled`.
The coupled line cannot have later-stage components or another endpoint; the
through line must continue through the symbol. Stroke and font size inherit the
fridge settings. Standalone `f.directional-coupler` and advanced
`f.resolve-couplers` are documented in the reference. See
`examples/block.typ` and `examples/fridge.json`.


Couplers now participate in stage-local component ordering. In a drawing block:

```typ
f.add.attenuator("main", "mix", db: 3)
f.add.attenuator("coupled", "mix", db: 10)
f.add.directional-coupler("main", "coupled", "mix", name: "dc")
f.add.filter("main", "mix", kind: "LPF")
```

For JSON, set `through-position` and `coupled-position` on a coupler descriptor.
Slots are one-based within the selected stage's ordinary components: 1 inserts
before the first component, 2 after the first, and count+1 appends. For the
reference arrangement, use slot 2 on both lines: an attenuator before the coupler
on each line and a filter after it on the through line. Omitted JSON positions
append. Block commands record the through-line position at call time; the coupled input
automatically follows all its stage components, including those added later.
Explicit positions can override that. The coupled line ends at the coupler, so components after its slot
are rejected. Multiple couplers must have consistent slot order on shared lines.
Layout returns `component-xs`, nested per line/component, for actual positions;
use these when a coupler introduces alignment space in a chain.

The coupled-line attenuator may be added after the coupler call when grouping
block commands by line. It is still placed before the coupled input. For JSON,
omit `coupled-position` to append after all components on that line at the stage.


## Not-connected termination

Use `{"type": "not-connected", "stage": "cold"}` in a JSON line's components,
or `f.add.not-connected(line, "cold")` in a fridge block. It draws the small open
bracket from the reference's line 1 and ends the line at that stage, omitting the
right endpoint label. It must be the final component and cannot share an endpoint
with another termination, switch, or connect.

Options in both APIs are scale (default 0.65), direction (right by default, or
left), optional label (empty), show-label, font-size, stroke, and minimum width.
Numeric font sizes/stroke thicknesses are points. The input anchor is
component-N-M.in. Standalone f.not-connected(component, x: ..., y: ...) follows
the other component renderers and can be used inside a named CeTZ group.
See examples/block.typ.

## Aligning added lines with the fridge right edge

`f.right-end(y)` (also `f.add.right-end`) returns a CeTZ coordinate at the normal
right endpoint, including the resolved lead. Pass a numeric canvas height or a
named coordinate whose height should be reused:

```typ
f.sline("component-1-1.port-3", f.right-end(-1))
f.zline("component-1-1.port-3", f.right-end("component-1-1.port-3"))
```

Works with ordinary draw.line and content too. It resolves through the
`fridge-right` anchor after layout, so stage spacing and style lead overrides
are included. It uses the diagram's normal endpoint even when some lines end
earlier at a component. Use inside a fridge drawing block; in a standalone
CeTZ canvas, define fridge-right yourself before using the helper.
