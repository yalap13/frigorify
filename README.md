# Frigorify

A small Typst library for dilution refrigerator wiring diagrams, built with [CeTZ](https://cetz-package.github.io/docs/). Stage boundaries are vertical and signal lines are horizontal, following the supplied Inkscape example.

## Quick start

From this repository:

```typst
#import "src/frigorify.typ": fridge
#fridge(json("examples/fridge.json"))
```

Or use a native Typst dictionary; see [examples/native.typ](examples/native.typ). The package entrypoint in `typst.toml` is ready for local package installation, but this library is not published on Typst Universe.

Compile the examples from the repository root (Typst needs `--root .` for their imports):

```sh
typst compile --root . examples/basic.typ examples/basic.pdf
typst compile --root . examples/native.typ examples/native.pdf
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
| `amplifier` | Equilateral triangle | `gain` (string), `direction` (`right` or `left`), `label` |
| `circulator` | One or two circles with open curved arrows | `direction` (`right` for counterclockwise, `left` for clockwise), `junctions` (1 or 2), `label` |
| `filter` | Pass-response symbol in a rectangle | `kind` (`LPF`, `HPF`, `BPF`, or their spelled-out names), `label` |

`label` overrides any generated component label. `width` optionally sets a minimum width in canvas units; measured label width still takes precedence. Extra configuration fields are ignored, allowing future metadata. JSON is only data: the library does not evaluate code in labels.

The first version models circulators as inline two-endpoint symbols. Third-port routing, connections between signal lines, switches, terminations, and probe enclosures are not yet implemented.

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

Use the `add` namespace to add components by wire and stage. This follows the block style of [Zap](https://typst.app/universe/package/zap), while collecting components before drawing so that stage spacing remains automatic.

```typst
#import "src/frigorify.typ" as f
#import "@preview/cetz:0.5.2": draw

#f.fridge(json("examples/block.json"), style: (
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
