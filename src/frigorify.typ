#import "@preview/cetz:0.5.2": canvas, draw

#import "builders.typ" as add

#import "components.typ": amplifier, attenuator, circulator, component-label, component-types, filter, fridge-component

#let validate-config(config) = {
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
#let fridge-layout(
  config,
  unit: 1cm,
  font-size: 9pt,
  min-stage-gap: 1.6,
  component-gap: 0.18,
  stage-padding: 0.22,
  line-gap: 0.85,
) = {
  validate-config(config)
  assert(unit > 0pt and font-size > 0pt, message: "unit and font-size must be positive lengths.")
  assert(
    min-stage-gap > 0 and component-gap >= 0 and stage-padding >= 0 and line-gap > 0,
    message: "Layout spacing must be positive (padding and component-gap may be zero).",
  )
  let widths = config.lines.map(wire => wire
    .at("components", default: ())
    .map(component => {
      let label = component-label(component)
      let label-width = measure(text(size: font-size, label)).width / unit + 0.24
      let base = if component.type == "circulator" { 0.54 * component.at("junctions", default: 1) } else if component.type == "amplifier" { 0.8 } else { 0.95 }
      calc.max(base, label-width, component.at("width", default: 0))
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
    line-gap: line-gap,
    component-gap: component-gap,
    stage-padding: stage-padding,
  )
}

#let fridge(
  config,
  unit: 1cm,
  font-size: 9pt,
  min-stage-gap: 1.6,
  component-gap: 0.18,
  stage-padding: 0.22,
  line-gap: 0.85,
  stroke: 0.7pt,
  stage-stroke: 1.2pt,
  lead: 0.65,
  style: (:),
  ..body,
) = context {
  assert(body.named() == (:) and body.pos().len() <= 1, message: "fridge accepts one optional drawing block.")
  let (config, extras) = add.assemble(config, body.pos().at(0, default: ()))
  let allowed = ("unit", "font-size", "min-stage-gap", "component-gap", "stage-padding", "line-gap", "stroke", "stage-stroke", "lead")
  assert(style.keys().all(key => key in allowed), message: "Unknown fridge style key.")
  let unit = style.at("unit", default: unit)
  let font-size = style.at("font-size", default: font-size)
  let min-stage-gap = style.at("min-stage-gap", default: min-stage-gap)
  let component-gap = style.at("component-gap", default: component-gap)
  let stage-padding = style.at("stage-padding", default: stage-padding)
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
              fridge-component(component, x: x, y: y, width: width, font-size: font-size, stroke: stroke)
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
