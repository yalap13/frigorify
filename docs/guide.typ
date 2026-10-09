= Using Frigorify

Import the package entrypoint as a namespace. From a document in this repository's
root, use `#import "src/frigorify.typ" as f`. Documents in `examples/` or `docs/`
use `../src/frigorify.typ`. Frigorify requires CeTZ 0.5.2. Tidy 0.4.3 is used only
to generate this reference.

== Public API map

#table(columns: (1fr, 2fr), inset: 5pt,
  [API], [Purpose],
  [`f.fridge`], [Render a complete diagram from JSON or a native dictionary, optionally with a drawing block.],
  [`f.fridge-layout`], [Measure final configuration in a Typst context and return geometry.],
  [`f.validate-config`], [Validate component configuration without drawing.],
  [`f.attenuator`, `f.amplifier`, `f.circulator`, `f.filter`, `f.rf-switch`, `f.fridge-component`], [Draw standalone symbols inside a CeTZ canvas.],
  [`f.short`, `f.load`], [Draw ground terminations at coordinates or named anchors.],
  [`f.sline`, `f.zline`], [Draw routed connections; also available through `f.add`.],
  [`f.add` component builders], [Append stage components before layout; includes attenuator, amplifier, circulator, filter, rf-switch, short, load.],
  [`f.add.connect`], [Replace a line endpoint with a connection to another line's circulator.],
  [`f.add.overlay`], [Draw using the final measured layout.],
  [`f.component-label`, `f.circulator-ports`, `f.connection-point`], [Advanced label and geometry helpers.],
  [`f.add.component`, `f.add.assemble`], [Advanced command construction and config assembly.],
)

== Configuration and placement

`stages` and `lines` are nonempty ordered arrays. Stages have unique string `id`
and string `label` fields. A component has `type` and an existing stage ID in
`stage`. Lines appear top to bottom; stages appear left to right. Components are
placed in stage order, keeping their array/call order within each stage.

```json
{
  "stages": [
    {"id": "room", "label": "300 K"},
    {"id": "mix", "label": "10 mK"}
  ],
  "lines": [{
    "id": "drive",
    "label": "Drive",
    "port": "9",
    "components": [
      {"type": "attenuator", "stage": "room", "db": 20},
      {"type": "filter", "stage": "mix", "kind": "LPF"}
    ]
  }]
}
```

Line `id` is optional and supplies the block selector. Without an ID, selectors
match `label`; integer selectors are one-based line numbers. Each selector must
match exactly one line. Missing labels use the line number. `port` labels the
right endpoint; omit it or use JSON null for no label. `color` is an optional
hex string such as `"#345c9c"`. `components` defaults to empty.

First components normally start at their stage boundary. Further components
follow to the right, separated by `component-gap`. Label measurement expands
stage intervals automatically. An explicit component `width` is a minimum
reservation, not a general symbol scaling control. Numeric geometry is in canvas
units (`unit: 1cm` by default); stroke/font sizes are Typst lengths.

Set the top-level JSON field `"first-stage-side": "left"`, or pass the matching
fridge keyword, to move first-stage chains before their boundary. Chain order
stays left to right. Incoming leads and labels shift to clear the longest chain.
Stage zero stays at x=0. An explicit keyword overrides JSON; `style` overrides
individual keywords. Later stages keep their normal placement.

== Component fields

#table(columns: (1fr, 2fr), inset: 5pt,
  [Type], [Fields and defaults],
  [`attenuator`], [`db: 0`, optional label and nonnegative padding-x/y. Minimum box 0.95 × 0.48. Standalone height may be supplied.],
  [`amplifier`], [`direction: "left"` or "right", `gain: ""`, optional label. Equilateral triangle height 0.48 and width about 0.416; reservation expands for labels or explicit width.],
  [`circulator`], [`junctions: 1` or 2, `direction: "right"` (counterclockwise) or "left" (clockwise), optional label. Circle diameter 0.54.],
  [`filter`], [`kind: "LPF"`. LPF/HPF/BPF and spelled-out names render response curves; other kinds render text. Optional label.],
  [`rf-switch`], [Optional label. Diameter 0.8; center is common input, six outer ports. Must be final on its line.],
  [`short`, `load`], [Stage terminations; scale, label, show-label, font-size, stroke, direction. Must be final on their line.],
)

Stage termination inputs are at x + 0.2; switch common inputs are at x + 0.4.
Their lines stop there and omit the usual right-end label. A stage termination
cannot share its endpoint with a switch, `connect`, or endpoint `termination`.
Labels are data; JSON does not evaluate Typst code.

== Block commands and anchors

```typ
#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2": draw
#f.fridge(config, stroke: 0.8pt, {
  f.add.attenuator("drive", "room", db: 20)
  f.add.circulator("output", "mix", junctions: 2)
  f.add.load("component-2-1.port-4-bottom", show-label: false)
  f.add.overlay(layout => {
    draw.content((layout.end / 2, -3), [Readout wiring])
  })
})
```

Components append to config components without changing the original config.
The block produces an array of commands and CeTZ elements. Component commands
are collected before measuring; terminations draw after all diagram anchors
exist; ordinary drawing elements and overlays follow in relative order.

Named anchors are `stage-ID`, `wire-N`, and `component-N-M`, where N and M are
one-based line and combined component indices. M follows config/addition order,
not sorted stage order. Shapes expose CeTZ bounding anchors such as north/east;
line paths expose start/end and percentage anchors. Explicit ports refer to
physical connection points independently of labels and reserved widths.

#table(columns: (1fr, 2fr), inset: 5pt,
  [Symbol], [Port anchors relative to component-N-M],
  [Circulator], [`in` / `port-1` left, `out` / `port-2` right; port-3 is first junction bottom, port-4 second junction bottom (double only). Append -top/-bottom to select side. Per-junction names are junction-J-port-1/2/3 and junction-J-port-3-top/bottom, with J one-based.],
  [RF switch], [`common` center; port-1 through port-6 clockwise from top. Ports 2 and 3 face right.],
  [Stage termination], [`in` at the line endpoint.],
  [Named standalone/port termination], [`name.in` input and `name.ground` first ground bar.],
)

== Connections and routing

```typ
f.add.connect("upper", to: "component-2-1.port-3-top")
f.zline("component-2-1.port-4-bottom", (4, -2), axis: "y", ratio: 60%)
f.sline((0, 0), (2, 1), stroke: 0.5pt)
```

`add.connect` ends an existing fridge line at a circulator on another line,
routing horizontally then vertically. The target can be declared later. Source
components must fit before the bend. It preserves line color/stroke and omits
its old endpoint label. JSON uses `"connect": "component-2-1.port-3-top"` on
the source line. A line cannot have both connect and an endpoint termination/switch.

`sline` and `zline` accept two or more CeTZ points or anchors, routing each
consecutive pair. sline bends once; zline uses three segments. Default axis x is
horizontal first; y is vertical first. zline defaults to ratio 50%; sline is ratio
100%. Percentages interpolate between endpoints. Numeric or length ratios use
CeTZ's distance along the vector between endpoints. Routing is planar and does
not avoid obstacles. Both forward CeTZ line styles, including name and mark.

Fridge stroke sets the default for draw.line, sline, zline, and overlay lines.
Explicit line strokes or CeTZ line style changes override it. Arbitrary port
connections inherit the diagram stroke, not automatically a source line's color.

== Ground terminations: JSON and block API

Prefer components when the mounting stage matters:

```json
{"type": "load", "stage": "mix", "scale": 0.5, "show-label": false}
```

```typ
f.add.short("drive", "room")
f.add.load("output", "mix", label: "Matched", font-size: 7pt)
```

Omit stage to attach at the usual right endpoint or a named port:

```typ
f.add.short("drive")
f.add.load("component-2-1.port-3-top", direction: "up", scale: 0.5)
```

JSON line endpoint syntax is `"termination": "short"` or `"termination": "load"`.
A dictionary supplies options: `"termination": {"type": "load", "scale": 0.5}`.
For port attachments, use a top-level array:

```json
"terminations": [
  {"target": "component-2-1.port-3-top", "type": "load", "direction": "up"}
]
```

Top-level targets can also be line IDs/labels or one-based line numbers. Symbol
options are available in JSON and block calls. Endpoint/port attachments accept
optional `name`; stage components accept minimum `width` and use component-N-M
for naming. For block endpoint calls, strings containing a dot mean an anchor.

#table(columns: (1fr, 1fr, 2fr), inset: 5pt,
  [Option], [Default], [Meaning],
  [scale], [0.65], [Positive geometry multiplier. 1 restores original geometry; text/stroke do not scale.],
  [direction], [down], [up/down/left/right from input toward ground.],
  [show-label], [true], [False hides the label.],
  [label], [50 Ω for load; empty for short], [Custom text; false, JSON null / Typst none, or empty string hides it.],
  [font-size], [Diagram font size], [JSON number in points; Typst number in points or a length.],
  [stroke], [Diagram stroke], [JSON number in points; Typst number in points or a length.],
)

Standalone `f.short(at, ...)` and `f.load(at, ...)` take CeTZ coordinates or anchors,
not line IDs. Their standalone font default is 9pt. Allow enough line-gap for
vertical symbols, labels, and port routing.

== Layout geometry and advanced helpers

`fridge-layout` requires a Typst context and final config; it does not assemble a
block. To include additions, first call `add.assemble(config, commands)`, which
returns the updated config and extras. `fridge` does this automatically.

#table(columns: (1fr, 2fr), inset: 5pt,
  [Layout field], [Meaning; all indices are zero-based],
  [stages], [Stage boundary x coordinates.],
  [end / gaps], [Right edge before lead; per-stage interval widths.],
  [widths / heights], [Nested per-line/per-component reservations and box heights. Non-attenuator heights are 0.48 placeholders, not symbol bounds.],
  [component-starts], [Nested per-line/per-stage chain starting x coordinates.],
  [left-extent], [Space before x=0 for first-stage chains, excluding lead.],
  [first-stage-side], [Resolved placement side.],
  [line-gap / component-gap / stage-padding], [Resolved spacing values.],
)

`component-label` resolves display text. `circulator-ports` returns a dictionary
of physical port coordinates. `connection-point(config, layout, target)` resolves
a circulator target to `(point: (x, y), row: zero-based-index)` before rendering.
Other exported source helpers are documented in the generated sections below;
they support advanced composition and are normally called by the public builders.

== Compiling examples and documentation

From the repository root:

```sh
typst compile --root . docs/reference.typ /tmp/frigorify-reference.pdf
python3 tests/check.py
```

Two examples live in examples/: basic.typ renders fridge.json; block.typ uses
native stages/lines and demonstrates component builders, switches, circulator ports,
right-edge routing, loads, a directional coupler, and not-connected termination.
Each compiles with --root .; behavior-specific regression fixtures live in tests/.

== Directional couplers

Amplifiers now default to direction left. Set direction right explicitly to reverse them.

`add.directional-coupler(through, coupled, stage, ..options)` places the three-port
symbol shown in the reference setup between two adjacent lines. The straight
through line continues, and the coupled line ends at the curved input. It follows block call order within its stage; layout aligns the symbol on both lines.
Optional fields are width (default 0.9), label (empty), and name (coupler-N).
The box spans both line heights; stroke and font size follow the diagram.

```typ
f.add.directional-coupler("main", "coupled", "mix", name: "dc")
```

JSON uses a top-level couplers array:

```json
"couplers": [
  {"through": "main", "coupled": "coupled", "stage": "mix", "name": "dc"}
]
```

Both line selectors accept IDs, labels, or one-based numbers. The coupled line
cannot have components at later stages or another endpoint termination/connection.
The through line must remain continuous through the symbol. Components at the same stage can precede or follow the coupler on the through line. Multiple couplers at a stage follow array/call
order. First-stage left placement is supported. Names should be unique.
Anchors are dc.main-in, dc.main-out, and dc.coupled. `fridge-layout` returns a
couplers array with resolved zero-based through/coupled/stage indices, x, width,
and name. `resolve-couplers` provides validated descriptors without measurement.

The standalone `f.directional-coupler` accepts x, y, coupled-y, width, label,
font-size, and stroke inside a CeTZ canvas. Wrap it in a named group to access
ports. See examples/block.typ and examples/fridge.json.


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


== Not-connected termination

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

== Aligning added lines with the fridge right edge

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
