#import "@preview/cetz:0.5.2": canvas, draw

#import "builders.typ" as add

#import "components.typ": amplifier, attenuator, circulator, component-label, component-types, filter, fridge-component

/// Validate the configuration, failing an assertion when its stages, lines, or component fields are invalid.
/// -> none
#let validate-config(
  /// Fridge configuration with nonempty `stages` and `lines` arrays. Stages have unique string `id` and `label` fields; components name their `type` and `stage`.
  /// -> dictionary
  config,
) = {
  assert(type(config) == dictionary, message: "Fridge configuration must be a dictionary.")
  assert("stages" in config and "lines" in config, message: "Configuration needs stages and lines arrays.")
  assert(type(config.stages) == array and config.stages.len() > 0, message: "stages must be a nonempty array.")
  assert(type(config.lines) == array and config.lines.len() > 0, message: "lines must be a nonempty array.")
  let ids = ()
  for stage in config.stages {
    assert(type(stage) == dictionary and "id" in stage and "label" in stage, message: "Each stage needs id and label.")
    assert(type(stage.id) == str and type(stage.label) == str, message: "Stage id and label must be strings.")
    assert(not stage.id in ids, message: "Duplicate stage id: " + stage.id)
    ids.push(stage.id)
  }
  for wire in config.lines {
    assert(type(wire) == dictionary, message: "Each line must be a dictionary.")
    for component in wire.at("components", default: ()) {
      assert(
        type(component) == dictionary and "type" in component and "stage" in component,
        message: "Each component needs type and stage.",
      )
      assert(component.type in component-types, message: "Unknown component type: " + repr(component.type))
      assert(component.stage in ids, message: "Unknown stage: " + repr(component.stage))
      assert(
        type(component-label(component)) == str,
        message: "Component labels, gains and filter kinds must be strings.",
      )
      assert(
        component.at("direction", default: "right") in ("left", "right"),
        message: "direction must be left or right.",
      )
      if component.type == "circulator" {
        assert(component.at("junctions", default: 1) in (1, 2), message: "Circulator junctions must be 1 or 2.")
      }
      if component.type == "filter" {
        assert(type(component.at("kind", default: "LPF")) == str, message: "Filter kind must be a string.")
      }
      if component.type == "attenuator" {
        for key in ("padding-x", "padding-y") {
          if key in component {
            assert(type(component.at(key)) in (int, float) and component.at(key) >= 0,
              message: "Attenuator padding must be a nonnegative number.")
          }
        }
      }
      if "width" in component {
        assert(
          type(component.width) in (int, float) and component.width > 0,
          message: "Component width must be a positive number.",
        )
      }
    }
  }
}

// Call in a Typst context. All returned geometry is in canvas units.
/// Measure labels and compute stage and component geometry. Call inside a Typst `context`.
/// Returns `stages` (stage x coordinates), `end`, `gaps`, and nested `widths` and `heights` arrays indexed by wire and component.
/// Also returns `line-gap`, `component-gap`, and `stage-padding`. Heights describe attenuator boxes; other entries are 0.48 placeholders.
/// -> dictionary
#let fridge-layout(
  /// Fridge configuration with nonempty `stages` and `lines` arrays. Stages have unique string `id` and `label` fields; components name their `type` and `stage`.
  /// -> dictionary
  config,
  /// Physical length of one canvas unit. Must be positive.
  /// -> length
  unit: 1cm,
  /// Label text size. Must be positive.
  /// -> length
  font-size: 9pt,
  /// Minimum horizontal interval after each stage, in canvas units. Must be positive.
  /// -> int | float
  min-stage-gap: 1.6,
  /// Nonnegative horizontal space between components at the same stage, in canvas units.
  /// -> int | float
  component-gap: 0.18,
  /// Nonnegative clearance after a component chain before the next boundary, in canvas units.
  /// -> int | float
  stage-padding: 0.22,
  /// Minimum padding on each horizontal side of attenuator text, in canvas units. Nonnegative; component `padding-x` overrides it. Boxes retain a minimum width of 0.95 units.
  /// -> int | float
  attenuator-padding-x: 0.12,
  /// Minimum padding on each vertical side of attenuator text, in canvas units. Nonnegative; component `padding-y` overrides it. Boxes retain a minimum height of 0.48 units.
  /// -> int | float
  attenuator-padding-y: 0.08,
  /// Vertical distance between wire centers, in canvas units. Must be positive; allow room for tall symbols and labels.
  /// -> int | float
  line-gap: 0.85,
) = {
  validate-config(config)
  assert(unit > 0pt and font-size > 0pt, message: "unit and font-size must be positive lengths.")
  assert(
    min-stage-gap > 0 and component-gap >= 0 and stage-padding >= 0 and line-gap > 0,
    message: "Layout spacing must be positive (padding and component-gap may be zero).",
  )
  assert(attenuator-padding-x >= 0 and attenuator-padding-y >= 0, message: "Attenuator padding must be nonnegative.")
  let widths = config.lines.map(wire => wire
    .at("components", default: ())
    .map(component => {
      let label = component-label(component)
      let padding = if component.type == "attenuator" { component.at("padding-x", default: attenuator-padding-x) } else { 0.12 }
      let label-width = measure(text(size: font-size, label)).width / unit + 2 * padding
      let base = if component.type == "circulator" { 0.54 * component.at("junctions", default: 1) } else if component.type == "amplifier" { 0.8 } else { 0.95 }
      calc.max(base, label-width, component.at("width", default: 0))
    }))
  let heights = config.lines.map(wire => wire.at("components", default: ()).map(component => {
    if component.type == "attenuator" {
      calc.max(0.48, measure(text(size: font-size, component-label(component))).height / unit
        + 2 * component.at("padding-y", default: attenuator-padding-y))
    } else { 0.48 }
  }))
  let positions = (0,)
  let gaps = ()
  for (index, stage) in config.stages.enumerate() {
    let required = min-stage-gap
    // Leave enough room for neighboring stage labels as well as components.
    if index < config.stages.len() - 1 {
      let next = config.stages.at(index + 1)
      required = calc.max(
        required,
        (measure(text(size: font-size, stage.label)).width + measure(text(size: font-size, next.label)).width)
          / (2 * unit)
          + 0.3,
      )
    }
    for (row, wire) in config.lines.enumerate() {
      let selected = wire.at("components", default: ()).enumerate().filter(pair => pair.at(1).stage == stage.id)
      let needed = selected.map(pair => widths.at(row).at(pair.at(0))).sum(default: 0)
      needed += calc.max(0, selected.len() - 1) * component-gap + stage-padding
      required = calc.max(required, needed)
    }
    gaps.push(required)
    positions.push(positions.last() + required)
  }
  (
    stages: positions.slice(0, config.stages.len()),
    end: positions.last(),
    gaps: gaps,
    widths: widths,
    heights: heights,
    line-gap: line-gap,
    component-gap: component-gap,
    stage-padding: stage-padding,
  )
}

/// Draw a dilution refrigerator wiring diagram with automatic stage spacing.
/// Components form a chain to the right of their named stage boundary.
/// Import from `src/frigorify.typ`; use its `add` namespace for drawing-block commands.
///
/// ```typ
/// #fridge(config, attenuator-padding-x: 0.3, attenuator-padding-y: 0.15)
/// ```
/// -> content
#let fridge(
  /// Fridge configuration with nonempty `stages` and `lines` arrays. Stages have unique string `id` and `label` fields; components name their `type` and `stage`.
  /// -> dictionary
  config,
  /// Physical length of one canvas unit. Must be positive.
  /// -> length
  unit: 1cm,
  /// Label text size. Must be positive.
  /// -> length
  font-size: 9pt,
  /// Minimum horizontal interval after each stage, in canvas units. Must be positive.
  /// -> int | float
  min-stage-gap: 1.6,
  /// Nonnegative horizontal space between components at the same stage, in canvas units.
  /// -> int | float
  component-gap: 0.18,
  /// Nonnegative clearance after a component chain before the next boundary, in canvas units.
  /// -> int | float
  stage-padding: 0.22,
  /// Minimum padding on each horizontal side of attenuator text, in canvas units. Nonnegative; component `padding-x` overrides it. Boxes retain a minimum width of 0.95 units.
  /// -> int | float
  attenuator-padding-x: 0.12,
  /// Minimum padding on each vertical side of attenuator text, in canvas units. Nonnegative; component `padding-y` overrides it. Boxes retain a minimum height of 0.48 units.
  /// -> int | float
  attenuator-padding-y: 0.08,
  /// Vertical distance between wire centers, in canvas units. Must be positive; allow room for tall symbols and labels.
  /// -> int | float
  line-gap: 0.85,
  /// Stroke for component outlines and wires without a configured color.
  /// -> length
  stroke: 0.7pt,
  /// Thickness of stage boundaries.
  /// -> length
  stage-stroke: 1.2pt,
  /// Nonnegative wire length outside the diagram intervals, in canvas units.
  /// -> int | float
  lead: 0.65,
  /// Diagram keyword options overriding individual arguments. Unknown keys are rejected.
  /// -> dictionary
  style: (:),
  /// At most one positional drawing block returning an array of `add` commands and CeTZ elements.
  /// Named arguments are rejected. Elements render after the diagram; `add.overlay` receives final geometry.
  /// -> arguments
  ..body,
) = context {
  assert(body.named() == (:) and body.pos().len() <= 1, message: "fridge accepts one optional drawing block.")
  let (config, extras) = add.assemble(config, body.pos().at(0, default: ()))
  let allowed = ("unit", "font-size", "min-stage-gap", "component-gap", "stage-padding", "attenuator-padding-x", "attenuator-padding-y", "line-gap", "stroke", "stage-stroke", "lead")
  assert(style.keys().all(key => key in allowed), message: "Unknown fridge style key.")
  let unit = style.at("unit", default: unit)
  let font-size = style.at("font-size", default: font-size)
  let min-stage-gap = style.at("min-stage-gap", default: min-stage-gap)
  let component-gap = style.at("component-gap", default: component-gap)
  let stage-padding = style.at("stage-padding", default: stage-padding)
  let attenuator-padding-x = style.at("attenuator-padding-x", default: attenuator-padding-x)
  let attenuator-padding-y = style.at("attenuator-padding-y", default: attenuator-padding-y)
  let line-gap = style.at("line-gap", default: line-gap)
  let stroke = style.at("stroke", default: stroke)
  let stage-stroke = style.at("stage-stroke", default: stage-stroke)
  let lead = style.at("lead", default: lead)
  let layout = fridge-layout(
    config,
    unit: unit,
    font-size: font-size,
    min-stage-gap: min-stage-gap,
    component-gap: component-gap,
    stage-padding: stage-padding,
    attenuator-padding-x: attenuator-padding-x,
    attenuator-padding-y: attenuator-padding-y,
    line-gap: line-gap,
  )
  assert(lead >= 0, message: "lead must be nonnegative.")
  canvas(length: unit, {
    import draw: content, line
    let bottom = -(config.lines.len() - 1) * line-gap - 0.45
    for (index, stage) in config.stages.enumerate() {
      let x = layout.stages.at(index)
      line((x, 0.52), (x, bottom), stroke: stage-stroke, name: "stage-" + stage.id)
      content((x, 0.85), text(size: font-size, weight: "bold", stage.label))
    }
    for (row, wire) in config.lines.enumerate() {
      let y = -row * line-gap
      let wire-stroke = wire.at("color", default: none)
      let wire-stroke = if wire-stroke == none { stroke } else { (paint: rgb(wire-stroke), thickness: stroke) }
      line((-lead, y), (layout.end + lead, y), stroke: wire-stroke, name: "wire-" + str(row + 1))
      content((-lead - 0.15, y), text(size: font-size, str(wire.at("label", default: row + 1))), anchor: "east")
      if wire.at("port", default: none) != none {
        content((layout.end + lead + 0.15, y), text(size: font-size, str(wire.port)), anchor: "west")
      }
      for (index, stage) in config.stages.enumerate() {
        let x = layout.stages.at(index)
        for (ci, component) in wire.at("components", default: ()).enumerate() {
          if component.stage == stage.id {
            let width = layout.widths.at(row).at(ci)
            draw.group({
              let rendered = if component.type == "attenuator" { component + (height: layout.heights.at(row).at(ci),) } else { component }
              fridge-component(rendered, x: x, y: y, width: width, font-size: font-size, stroke: stroke)
            }, name: "component-" + str(row + 1) + "-" + str(ci + 1))
            x += width + component-gap
          }
        }
      }
    }
    // Ordinary CeTZ elements render after the fridge; callbacks use final layout.
    for extra in extras {
      if type(extra) == dictionary and extra.at("_frigorify", default: none) == "overlay" {
        (extra.callback)(layout)
      } else { (extra,) }
    }
  })
}
