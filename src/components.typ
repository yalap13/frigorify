#import "terminations.typ" as terminations
#import "@preview/cetz:0.5.2": draw

// Configuration is deliberately made of JSON-compatible dictionaries and arrays.
/// Supported component type strings for `fridge-component` and `add.component`.
/// -> array
#let component-types = ("attenuator", "circulator", "amplifier", "filter", "rf-switch", "short", "load", "not-connected")

/// Resolve the displayed component label without drawing. Attenuators use `db` plus dB,
/// amplifiers use `gain`, and response-symbol filters default to an empty label.
/// Explicit `label` overrides these defaults. Loads default to "50 Ω"; shorts have no
/// default label. For terminations, `show-label: false`, `label: false`, `none`, or an
/// empty string suppresses the label. This function is also re-exported by the main module.
/// -> str
#let component-label(
  /// Component dictionary. See the function description for supported fields.
  /// -> dictionary
  component,
) = {
  if component.type in ("short", "load", "not-connected") { terminations.termination-label(component, load: component.type == "load") }
  else if "label" in component { component.label } else if component.type == "attenuator" {
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

/// Draw an equilateral amplifier triangle of height 0.48 and width about 0.416 canvas units.
/// Automatic layout reserves the triangle width, expanding for labels or explicit `width`. `direction` is `left` (default) or `right`. An explicit `label`, or otherwise the string `gain`, appears above the triangle. Use inside a CeTZ canvas. Import from `src/frigorify.typ` or `src/components.typ`.
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
  let left = component.at("direction", default: "left") == "left"
  let triangle-width = calc.sqrt(3) * half-height
  let a = if left { x + triangle-width } else { x }
  let b = if left { x } else { x + triangle-width }
  line((a, y - half-height), (b, y), (a, y + half-height), close: true, fill: white, stroke: stroke)
  if label != "" { content((x + triangle-width / 2, y + 0.38), text(size: font-size, label)) }
}

// Shared geometry for rendered anchors and fridge endpoint connections.
/// Return numerical circulator port coordinates for custom layouts, without drawing.
/// `in` / `port-1` are left, `out` / `port-2` are right. `port-3` and `port-4`
/// are the first and second junction bottoms; append `-top` or `-bottom` to choose
/// the side. Each junction also has `junction-J-port-1/2/3` and `-3-top/bottom`.
/// J is one-based. Port 4 exists only for two junctions. Coordinates ignore label
/// bounds, reserved width, and arrow direction. Re-exported by the main module.
/// -> dictionary
#let circulator-ports(
  /// Circulator dictionary; `junctions` defaults to 1 and must be 1 or 2.
  /// -> dictionary
  component,
  /// Left edge of the first circle, in canvas units.
  /// -> int | float
  x: 0,
  /// Center of the inline line, in canvas units.
  /// -> int | float
  y: 0,
) = {
  let junctions = component.at("junctions", default: 1)
  let ports = ("in": (x, y), out: (x + junctions * 0.54, y))
  ports.insert("port-1", ports.at("in"))
  ports.insert("port-2", ports.at("out"))
  for index in range(junctions) {
    let mid = x + 0.27 + index * 0.54
    let prefix = "junction-" + str(index + 1) + "-port-"
    ports.insert(prefix + "1", (mid - 0.27, y))
    ports.insert(prefix + "2", (mid + 0.27, y))
    for prefix in ("port-" + str(index + 3), prefix + "3") {
      ports.insert(prefix, (mid, y - 0.27))
      ports.insert(prefix + "-top", (mid, y + 0.27))
      ports.insert(prefix + "-bottom", (mid, y - 0.27))
    }
  }
  ports
}

/// Ports: `in` / `port-1` at the left, `out` / `port-2` at the right,
/// and `port-3` at the bottom of the first junction (`port-4` for the second).
/// Each junction also exposes `junction-J-port-1/2/3` (left/right/bottom, J is one-based).
/// Use `port-3-top` / `port-3-bottom` and `port-4-top` / `port-4-bottom`
/// to choose the side. Unsuffixed anchors retain their bottom positions.
/// Anchor positions do not change with arrow direction or labels.
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
  for (name, point) in circulator-ports(component, x: x, y: y) {
    draw.anchor(name, point)
  }
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

/// Draw an RF switch with one common center port and six outer ports, diameter 0.8 canvas units.
/// The input enters from the left and ends at `common`. Outer anchors `port-1` through `port-6`
/// run clockwise from the top. Use inside a named CeTZ group to connect these anchors.
/// -> array
#let rf-switch(
  /// Component dictionary; optional `label` appears above the switch.
  /// -> dictionary
  component,
  /// Left edge, in canvas units.
  /// -> int | float
  x: 0,
  /// Center of the input wire, in canvas units.
  /// -> int | float
  y: 0,
  /// Reserved horizontal space, in canvas units.
  /// -> int | float
  width: 0.8,
  /// Label text size.
  /// -> length
  font-size: 9pt,
  /// Outline and input wire thickness.
  /// -> length
  stroke: 0.7pt,
) = {
  let mid = x + 0.4
  draw.circle((mid, y), radius: 0.4, fill: white, stroke: stroke)
  draw.line((x, y), (mid, y), stroke: stroke)
  draw.circle((mid, y), radius: 0.035, fill: white, stroke: stroke)
  draw.anchor("common", (mid, y))
  for index in range(6) {
    let angle = 90deg - index * 60deg
    let port = (mid + 0.28 * calc.cos(angle), y + 0.28 * calc.sin(angle))
    draw.circle(port, radius: 0.035, fill: white, stroke: stroke)
    draw.anchor("port-" + str(index + 1), port)
  }
  let label = component-label(component)
  if label != "" { draw.content((mid, y + 0.55), text(size: font-size, label)) }
}

/// Draw an open, not-connected bracket terminating a line, matching the reference diagram.
/// Input is at (x + 0.2, y), exposed as `in`. Default direction right makes a closing
/// bracket; left mirrors it. Supports scale (default 0.65), optional label/show-label,
/// numeric font-size/stroke in points, and Typst physical styles. Use inside a named
/// CeTZ group for anchors; use add.not-connected(line, stage) in fridge blocks.
/// -> array
#let not-connected(
  /// Dictionary with type not-connected and optional scale, direction, label, show-label, font-size, stroke.
  /// -> dictionary
  component,
  /// Left edge of reserved component space, in canvas units.
  /// -> int | float
  x: 0,
  /// Input line center, in canvas units.
  /// -> int | float
  y: 0,
  /// Reserved width; does not scale the symbol.
  /// -> int | float
  width: 0.4,
  /// Default label font size.
  /// -> length
  font-size: 9pt,
  /// Default stroke thickness.
  /// -> length
  stroke: 0.7pt,
) = {
  let options = terminations.termination-options(component)
  let scale = options.at("scale", default: 0.65)
  let sign = if component.at("direction", default: "right") == "left" { -1 } else { 1 }
  let input = x + 0.2
  let end = input + sign * 0.12 * scale
  let stroke = options.at("stroke", default: stroke)
  draw.line((input, y), (end, y), stroke: stroke)
  draw.line((input, y + 0.12 * scale), (end, y + 0.12 * scale),
    (end, y - 0.12 * scale), (input, y - 0.12 * scale), stroke: stroke)
  draw.anchor("in", (input, y))
  let label = component-label(component)
  if label != "" { draw.content((input, y + 0.25 * scale), text(size: options.at("font-size", default: font-size), label)) }
}

// Stage termination input is slightly right of the stage boundary so ground bars
// and resistor outlines remain clear of that boundary.
/// Advanced renderer used by `fridge-component` for `short` and `load` dictionaries.
/// The input is at (x + 0.2, y), exposed as `in` in the surrounding group.
/// Options are `direction`, `scale`, `label`, `show-label`, `font-size`, and `stroke`.
/// Component font/stroke overrides take precedence over renderer arguments.
/// -> array
#let termination-component(
  /// Dictionary with `type: "short"` or `type: "load"`.
  /// -> dictionary
  component,
  /// Left edge of reserved component space, in canvas units.
  /// -> int | float
  x: 0,
  /// Input line height, in canvas units.
  /// -> int | float
  y: 0,
  /// Reserved width; does not resize the termination geometry (use `scale`).
  /// -> int | float
  width: 1,
  /// Default label size, overridden by component `font-size`.
  /// -> length
  font-size: 9pt,
  /// Default outline thickness, overridden by component `stroke`.
  /// -> length
  stroke: 0.7pt,
) = {
  let render = if component.type == "short" { terminations.short } else { terminations.load }
  let options = (:)
  for key in ("direction", "scale", "label", "show-label", "font-size", "stroke") {
    if key in component { options.insert(key, component.at(key)) }
  }
  render((x + 0.2, y), ..(font-size: font-size, stroke: stroke, ..options))
  draw.anchor("in", (x + 0.2, y))
}

// Keep the configuration-driven entrypoint shared by all component types.
// width reserves horizontal space; triangles and circles have fixed sizes.
/// Draw a standalone CeTZ symbol selected by the component dictionary's `type`.
/// Types are attenuator, amplifier, circulator, filter, rf-switch, short, load, and not-connected.
/// `stage` is not needed for standalone drawing. Termination inputs are offset 0.2
/// from x; switches use x + 0.4. This function draws only the symbol, not a complete
/// input/output line. Wrap in a named CeTZ group to expose its port anchors.
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
  let renderers = (attenuator: attenuator, amplifier: amplifier, circulator: circulator, filter: filter, rf-switch: rf-switch, short: termination-component, load: termination-component, not-connected: not-connected)
  assert(component.type in renderers, message: "Unknown component type: " + repr(component.type))
  let render = renderers.at(component.type)
  render(component, x: x, y: y, width: width, font-size: font-size, stroke: stroke)
}
