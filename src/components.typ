#import "@preview/cetz:0.5.2": draw

// Configuration is deliberately made of JSON-compatible dictionaries and arrays.
#let component-types = ("attenuator", "circulator", "amplifier", "filter")

/// Resolve a component label. An explicit `label` takes precedence; attenuators use `db` plus dB, amplifiers use `gain`, and response-symbol filters default to an empty label.
/// -> str
#let component-label(
  /// Component dictionary. See the function description for supported fields.
  /// -> dictionary
  component,
) = {
  if "label" in component { component.label } else if component.type == "attenuator" {
    str(component.at("db", default: 0)) + " dB"
  } else if component.type == "amplifier" { component.at("gain", default: "") } else if component.type == "filter" {
    let kind = component.at("kind", default: "LPF")
    if lower(kind) in ("lpf", "low-pass", "lowpass", "hpf", "high-pass", "highpass", "bpf", "band-pass", "bandpass") {
      ""
    } else { kind }
  } else { "" }
}

// Each function emits CeTZ elements, for use inside a canvas.
// x is the symbol's left edge and y is the wire center.
/// Draw a rectangular attenuator centered on the wire. The label defaults to `db` (0) followed by dB. The component dictionary can specify `height` (default 0.48 canvas units). Text padding is measured by `fridge` and `fridge-layout`; standalone drawing uses the supplied width and height. Use inside a CeTZ canvas. Import from `src/frigorify.typ` or `src/components.typ`.
/// -> array
#let attenuator(
  /// Component dictionary. See the function description for supported fields.
  /// -> dictionary
  component,
  /// Left edge of the symbol, in canvas units.
  /// -> int | float
  x: 0,
  /// Wire center and vertical center of the symbol, in canvas units.
  /// -> int | float
  y: 0,
  /// Reserved horizontal space in canvas units. Sets rectangle width; triangles and circles have fixed geometry. Standalone rendering does not measure labels automatically.
  /// -> int | float
  width: 1,
  /// Label text size. Must be positive.
  /// -> length
  font-size: 9pt,
  /// Stroke for component outlines and wires without a configured color.
  /// -> length
  stroke: 0.7pt,
) = {
  import draw: content, rect
  let half-height = component.at("height", default: 0.48) / 2
  rect((x, y - half-height), (x + width, y + half-height), fill: white, stroke: stroke)
  content((x + width / 2, y), text(size: font-size, component-label(component)))
}

/// Draw an equilateral amplifier triangle of height 0.48 canvas units. `direction` is `right` (default) or `left`. An explicit `label`, or otherwise the string `gain`, appears above the triangle. Use inside a CeTZ canvas. Import from `src/frigorify.typ` or `src/components.typ`.
/// -> array
#let amplifier(
  /// Component dictionary. See the function description for supported fields.
  /// -> dictionary
  component,
  /// Left edge of the symbol, in canvas units.
  /// -> int | float
  x: 0,
  /// Wire center and vertical center of the symbol, in canvas units.
  /// -> int | float
  y: 0,
  /// Reserved horizontal space in canvas units. Sets rectangle width; triangles and circles have fixed geometry. Standalone rendering does not measure labels automatically.
  /// -> int | float
  width: 1,
  /// Label text size. Must be positive.
  /// -> length
  font-size: 9pt,
  /// Stroke for component outlines and wires without a configured color.
  /// -> length
  stroke: 0.7pt,
) = {
  import draw: content, line
  let label = component-label(component)
  let half-height = 0.24
  let left = component.at("direction", default: "right") == "left"
  let triangle-width = calc.sqrt(3) * half-height
  let a = if left { x + triangle-width } else { x }
  let b = if left { x } else { x + triangle-width }
  line((a, y - half-height), (b, y), (a, y + half-height), close: true, fill: white, stroke: stroke)
  if label != "" { content((x + triangle-width / 2, y + 0.38), text(size: font-size, label)) }
}

/// Draw one or two circulator junctions of diameter 0.54 canvas units each. `junctions` is 1 (default) or 2; two circles touch inside a shared rectangle. `direction` is `right` (default, counterclockwise) or `left` (clockwise). An optional `label` appears above. Use inside a CeTZ canvas. Import from `src/frigorify.typ` or `src/components.typ`.
/// -> array
#let circulator(
  /// Component dictionary. See the function description for supported fields.
  /// -> dictionary
  component,
  /// Left edge of the symbol, in canvas units.
  /// -> int | float
  x: 0,
  /// Wire center and vertical center of the symbol, in canvas units.
  /// -> int | float
  y: 0,
  /// Reserved horizontal space in canvas units. Sets rectangle width; triangles and circles have fixed geometry. Standalone rendering does not measure labels automatically.
  /// -> int | float
  width: 1,
  /// Label text size. Must be positive.
  /// -> length
  font-size: 9pt,
  /// Stroke for component outlines and wires without a configured color.
  /// -> length
  stroke: 0.7pt,
) = {
  import draw: arc, circle, content, group, rect-around
  let junctions = component.at("junctions", default: 1)
  assert(junctions in (1, 2), message: "Circulator junctions must be 1 or 2.")
  let label = component-label(component)
  group({
    for index in range(junctions) {
      let mid = x + 0.27 + index * 0.54
      circle((mid, y), radius: 0.27, fill: white, stroke: stroke, name: "junction-" + str(index))
      let reverse = component.at("direction", default: "right") == "left"
      arc(
        (mid, y),
        anchor: "origin",
        start: if reverse { 40deg } else { 140deg },
        delta: if reverse { -250deg } else { 250deg },
        radius: 0.17,
        stroke: stroke,
        mark: (end: "curved-stealth", scale: 0.3),
      )
    }
    if junctions == 2 {
      rect-around("junction-0", "junction-1", padding: 0, stroke: stroke, fill: none)
    }
  })
  if label != "" { content((x + junctions * 0.27, y + 0.4), text(size: font-size, label)) }
}

/// Draw a rectangular filter with an LPF, HPF, or BPF response symbol. `kind` defaults to `LPF` and also accepts spelled-out names. An explicit `label` appears above response symbols; other kinds such as RC render text inside the box. Use inside a CeTZ canvas. Import from `src/frigorify.typ` or `src/components.typ`.
/// -> array
#let filter(
  /// Component dictionary. See the function description for supported fields.
  /// -> dictionary
  component,
  /// Left edge of the symbol, in canvas units.
  /// -> int | float
  x: 0,
  /// Wire center and vertical center of the symbol, in canvas units.
  /// -> int | float
  y: 0,
  /// Reserved horizontal space in canvas units. Sets rectangle width; triangles and circles have fixed geometry. Standalone rendering does not measure labels automatically.
  /// -> int | float
  width: 1,
  /// Label text size. Must be positive.
  /// -> length
  font-size: 9pt,
  /// Stroke for component outlines and wires without a configured color.
  /// -> length
  stroke: 0.7pt,
) = {
  import draw: content, line, rect
  let kind = lower(component.at("kind", default: "LPF"))
  let half-height = 0.24
  rect((x, y - half-height), (x + width, y + half-height), fill: white, stroke: stroke)
  let left = x + 0.15 * width
  let right = x + 0.85 * width
  let mid = x + width / 2
  if kind in ("lpf", "low-pass", "lowpass") {
    line((left, y + 0.12), (mid, y + 0.12), (right, y - 0.12), stroke: stroke)
  } else if kind in ("hpf", "high-pass", "highpass") {
    line((left, y - 0.12), (mid, y + 0.12), (right, y + 0.12), stroke: stroke)
  } else if kind in ("bpf", "band-pass", "bandpass") {
    line(
      (left, y - 0.12),
      (x + 0.35 * width, y + 0.12),
      (x + 0.65 * width, y + 0.12),
      (right, y - 0.12),
      stroke: stroke,
    )
  } else {
    // Preserve labels for other existing filter kinds such as RC.
    content((mid, y), text(size: font-size, component.at("label", default: component.at("kind", default: "LPF"))))
  }
  if kind in ("lpf", "low-pass", "lowpass", "hpf", "high-pass", "highpass", "bpf", "band-pass", "bandpass") {
    let label = component-label(component)
    if label != "" { content((mid, y + 0.38), text(size: font-size, label)) }
  }
}

// Keep the configuration-driven entrypoint shared by all component types.
// width reserves horizontal space; triangles and circles have fixed sizes.
/// Draw a standalone CeTZ symbol selected by the component dictionary's `type`.
/// Use inside a CeTZ canvas. Import from `src/frigorify.typ` or `src/components.typ`.
/// -> array
#let fridge-component(
  /// Component dictionary. See the function description for supported fields.
  /// -> dictionary
  component,
  /// Left edge of the symbol, in canvas units.
  /// -> int | float
  x: 0,
  /// Wire center and vertical center of the symbol, in canvas units.
  /// -> int | float
  y: 0,
  /// Reserved horizontal space in canvas units. Sets rectangle width; triangles and circles have fixed geometry. Standalone rendering does not measure labels automatically.
  /// -> int | float
  width: 1,
  /// Label text size. Must be positive.
  /// -> length
  font-size: 9pt,
  /// Stroke for component outlines and wires without a configured color.
  /// -> length
  stroke: 0.7pt,
) = {
  let renderers = (attenuator: attenuator, amplifier: amplifier, circulator: circulator, filter: filter)
  assert(component.type in renderers, message: "Unknown component type: " + repr(component.type))
  let render = renderers.at(component.type)
  render(component, x: x, y: y, width: width, font-size: font-size, stroke: stroke)
}
