#import "couplers.typ": directional-coupler, resolve-couplers
#import "terminations.typ": short, load, termination-options
#import "lines.typ": sline, zline, right-end
#import "@preview/cetz:0.5.2": canvas, draw

#import "builders.typ" as add

#import "components.typ": amplifier, attenuator, circulator, circulator-ports, component-label, component-types, filter, rf-switch, not-connected, fridge-component

/// Validate stages, lines, component types, labels, directions, sizes, and endpoint
/// component ordering, failing an assertion for invalid data. No drawing or measurement.
/// This validates component configuration; `fridge` additionally assembles and checks
/// endpoint/port termination commands and resolves connection anchors during rendering.
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
        if component.type in ("short", "load") {
          component.at("direction", default: "down") in ("up", "down", "left", "right")
        } else { component.at("direction", default: "right") in ("left", "right") },
        message: "Invalid component direction.",
      )
      if component.type in ("short", "load", "not-connected") { let _ = termination-options(component) }
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
    let ordered = wire.at("components", default: ()).sorted(key: c => ids.position(id => id == c.stage))
    let switches = ordered.enumerate().filter(pair => pair.last().type == "rf-switch")
    assert(switches.len() <= 1 and (switches.len() == 0 or switches.first().first() == ordered.len() - 1),
      message: "RF switch must be the final component on its wire.")
    let terminations = ordered.enumerate().filter(pair => pair.last().type in ("short", "load", "not-connected"))
    assert(terminations.len() <= 1 and (terminations.len() == 0 or terminations.first().first() == ordered.len() - 1),
      message: "Termination must be the final component on its line.")
    assert(terminations.len() == 0 or (not "connect" in wire and not "termination" in wire and switches.len() == 0),
      message: "A termination component cannot share its line with another endpoint connection or termination.")
  }
}

// Call in a Typst context. All returned geometry is in canvas units.
/// Measure labels and compute stage and component geometry. Call inside a Typst `context`.
/// Pass the final config; this function does not collect drawing-block commands.
/// Stage and component indices in geometry arrays are zero-based. Component indices
/// follow original config order even when physical placement follows stage order.
/// `couplers` contains resolved paired-line symbols with x, width, name and zero-based
/// through/coupled/stage indices. `component-xs` gives each component's actual x.
/// Paired coupler slots align both lines and preserve component ordering.
/// `end` is the right edge of the last interval, excluding `lead`; `left-extent`
/// excludes the incoming lead. Empty intervals keep `min-stage-gap`.
/// Returns `stages` (stage x coordinates), `end`, `gaps`, and nested `widths` and `heights` arrays indexed by wire and component.
/// Returns `component-starts` (per-line/per-stage chain x positions), `left-extent`,
/// and the resolved `first-stage-side`. Also returns `line-gap`, `component-gap`, and `stage-padding`. Heights describe attenuator boxes; other entries are 0.48 placeholders.
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
  /// Place first-stage chains on `left` or `right`. None uses the config's
  /// `first-stage-side` field, defaulting to `right`.
  /// -> none | str
  first-stage-side: none,
) = {
  validate-config(config)
  let first-stage-side = if first-stage-side == none { config.at("first-stage-side", default: "right") } else { first-stage-side }
  assert(first-stage-side in ("left", "right"), message: "first-stage-side must be left or right.")
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
      let label-size = if component.type in ("short", "load", "not-connected") { termination-options(component).at("font-size", default: font-size) } else { font-size }
      let label-width = measure(text(size: label-size, label)).width / unit + 2 * padding
      if component.type in ("short", "load", "not-connected") {
        let scale = component.at("scale", default: 0.65)
        return calc.max(0.2 + 0.18 * scale, if label == "" { 0 } else { 0.2 + 0.13 * scale + label-width },
          component.at("width", default: 0))
      }
      let base = if component.type == "circulator" { 0.54 * component.at("junctions", default: 1) } else if component.type == "amplifier" { calc.sqrt(3) * 0.24 } else if component.type == "rf-switch" { 0.8 } else if component.type == "short" { 0.45 } else { 0.95 }
      calc.max(base, label-width, component.at("width", default: 0))
    }))
  let heights = config.lines.map(wire => wire.at("components", default: ()).map(component => {
    if component.type == "attenuator" {
      calc.max(0.48, measure(text(size: font-size, component-label(component))).height / unit
        + 2 * component.at("padding-y", default: attenuator-padding-y))
    } else { 0.48 }
  }))
  let couplers = resolve-couplers(config)
  let coupler-widths = couplers.map(c => calc.max(c.at("width", default: 0.9),
    measure(text(size: font-size, c.at("label", default: ""))).width / unit + 0.24))
  // Consume each line's stage components up to each paired coupler slot, then
  // synchronize the two cursors before continuing with downstream components.
  let component-offsets = widths.map(row => row.map(_ => 0))
  let stage-lengths = config.lines.map(_ => config.stages.map(_ => 0))
  let coupler-offsets = couplers.map(_ => 0)
  for (si, stage) in config.stages.enumerate() {
    let selected = config.lines.map(wire => wire.at("components", default: ()).enumerate().filter(pair => pair.last().stage == stage.id).map(pair => pair.first()))
    let cursors = config.lines.map(_ => 0)
    let consumed = config.lines.map(_ => 0)
    for (ci, c) in couplers.enumerate() {
      if c.stage == si {
        for (row, slot) in ((c.through, c.at("through-position")), (c.coupled, c.at("coupled-position"))) {
          assert(slot - 1 >= consumed.at(row), message: "Coupler positions must follow coupler order on each line.")
          for index in range(consumed.at(row), slot - 1) {
            let component = selected.at(row).at(index)
            component-offsets.at(row).at(component) = cursors.at(row)
            cursors.at(row) += widths.at(row).at(component) + component-gap
          }
          consumed.at(row) = slot - 1
        }
        let x = calc.max(cursors.at(c.through), cursors.at(c.coupled))
        coupler-offsets.at(ci) = x
        cursors.at(c.through) = x + coupler-widths.at(ci) + component-gap
        cursors.at(c.coupled) = x + coupler-widths.at(ci) + component-gap
      }
    }
    for row in range(config.lines.len()) {
      for index in range(consumed.at(row), selected.at(row).len()) {
        let component = selected.at(row).at(index)
        component-offsets.at(row).at(component) = cursors.at(row)
        cursors.at(row) += widths.at(row).at(component) + component-gap
      }
      stage-lengths.at(row).at(si) = calc.max(0, cursors.at(row) - component-gap)
    }
  }
  let stage-used = config.stages.enumerate().map(((si, _)) => stage-lengths.map(row => row.at(si)).fold(0, calc.max))
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
      if index != 0 or first-stage-side == "right" { required = calc.max(required, needed) }
    }
    if index != 0 or first-stage-side == "right" {
      required = calc.max(required, stage-used.at(index) + stage-padding)
    }
    gaps.push(required)
    positions.push(positions.last() + required)
  }
  let shared-left = couplers.any(c => c.stage == 0)
  let component-starts = stage-lengths.map(lengths => config.stages.enumerate().map(((si, _)) => {
    positions.at(si) - (if si == 0 and first-stage-side == "left" { if shared-left { stage-used.first() } else { lengths.first() } } else { 0 })
  }))
  let component-xs = config.lines.enumerate().map(((row, wire)) => wire.at("components", default: ()).enumerate().map(((ci, c)) => {
    let si = config.stages.position(stage => stage.id == c.stage)
    component-starts.at(row).at(si) + component-offsets.at(row).at(ci)
  }))
  let coupler-positions = couplers.enumerate().map(((ci, c)) => (
    ..c, x: component-starts.at(c.through).at(c.stage) + coupler-offsets.at(ci),
    width: coupler-widths.at(ci), name: c.at("name", default: "coupler-" + str(ci + 1)),
  ))
  let left-extent = component-starts.map(starts => -starts.first()).fold(0, calc.max)
  (
    couplers: coupler-positions,
    component-xs: component-xs,
    component-starts: component-starts,
    left-extent: left-extent,
    first-stage-side: first-stage-side,
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

// Compute a circulator endpoint before drawing, so forward references work.
/// Resolve a named circulator port to numerical coordinates before rendering.
/// Supports forward references. Returns `(point: (x, y), row: zero-based-line-index)`.
/// Geometry includes left-of-first-stage placement. Rejects unknown/non-circulator
/// components and unavailable ports. Re-exported in the main module for custom routing.
/// -> dictionary
#let connection-point(
  /// Final config including all component additions (use `add.assemble` if needed).
  /// -> dictionary
  config,
  /// Matching `fridge-layout` result.
  /// -> dictionary
  layout,
  /// Named circulator anchor, e.g. `component-2-1.port-3-top`.
  /// -> str
  target,
) = {
  assert(type(target) == str, message: "Connection target must be a circulator anchor string.")
  let parts = target.split(".")
  assert(parts.len() == 2, message: "Connection target must name a circulator component and port.")
  let names = (:)
  for (row, wire) in config.lines.enumerate() {
    for (si, stage) in config.stages.enumerate() {
      let x = layout.component-starts.at(row).at(si)
      for (ci, component) in wire.at("components", default: ()).enumerate() {
        if component.stage == stage.id {
            x = layout.component-xs.at(row).at(ci)
          names.insert("component-" + str(row + 1) + "-" + str(ci + 1), (component: component, x: x, y: -row * layout.line-gap, row: row))
          x += layout.widths.at(row).at(ci) + layout.component-gap
        }
      }
    }
  }
  assert(parts.first() in names, message: "Unknown connection component: " + parts.first())
  let entry = names.at(parts.first())
  assert(entry.component.type == "circulator", message: "Connection target must be a circulator.")
  let ports = circulator-ports(entry.component, x: entry.x, y: entry.y)
  assert(parts.last() in ports, message: "Unknown circulator connection port: " + parts.last())
  (point: ports.at(parts.last()), row: entry.row)
}

/// Draw a dilution refrigerator wiring diagram with automatic stage spacing.
/// Components form a chain to the right of their named stage boundary.
/// Use `first-stage-side: "left"` to place the first stage’s chains before its boundary.
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
  /// Place first-stage chains on `left` or `right`. None uses the config's
  /// `first-stage-side` field, defaulting to `right`.
  /// -> none | str
  first-stage-side: none,
  /// Stroke for component outlines, wires without a configured color, and drawing-block
  /// lines (`draw.line`, `sline`, and `zline`) unless explicitly overridden.
  /// -> length
  stroke: 0.7pt,
  /// Thickness of stage boundaries.
  /// -> length
  stage-stroke: 1.2pt,
  /// Nonnegative wire length outside the diagram intervals, in canvas units.
  /// -> int | float
  lead: 0.65,
  /// Diagram keyword options overriding individual arguments. Unknown keys are rejected.
  /// Accepted keys: unit, font-size, min-stage-gap, component-gap, stage-padding,
  /// attenuator-padding-x/y, line-gap, first-stage-side, stroke, stage-stroke, lead.
  /// -> dictionary
  style: (:),
  /// At most one positional drawing block returning an array of `add` commands and CeTZ elements.
  /// Named arguments are rejected. Commands are collected before layout; named component
  /// anchors are `component-N-M` (one-based line and combined component indices), stages
  /// are `stage-ID`, and lines are `wire-N`. Terminations draw after components;
  /// ordinary CeTZ elements render afterward. `add.overlay` receives final geometry.
  /// -> arguments
  ..body,
) = context {
  assert(body.named() == (:) and body.pos().len() <= 1, message: "fridge accepts one optional drawing block.")
  let (config, extras) = add.assemble(config, body.pos().at(0, default: ()))
  let allowed = ("unit", "font-size", "min-stage-gap", "component-gap", "stage-padding", "attenuator-padding-x", "attenuator-padding-y", "line-gap", "stroke", "stage-stroke", "lead", "first-stage-side")
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
  let first-stage-side = style.at("first-stage-side", default: first-stage-side)
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
    first-stage-side: first-stage-side,
  )
  assert(lead >= 0, message: "lead must be nonnegative.")
  canvas(length: unit, {
    import draw: content, line
    draw.set-style(line: (stroke: stroke))
    draw.anchor("fridge-right", (layout.end + lead, 0))
    let wire-start = -layout.left-extent - lead
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
      let wire-end = layout.end + lead
      let has-switch = false
      let has-termination = false
      for (si, stage) in config.stages.enumerate() {
        let x = layout.component-starts.at(row).at(si)
        for (ci, component) in wire.at("components", default: ()).enumerate() {
          if component.stage == stage.id {
            x = layout.component-xs.at(row).at(ci)
            if component.type == "rf-switch" { wire-end = x + 0.4; has-switch = true }
            if component.type in ("short", "load", "not-connected") { wire-end = x + 0.2; has-termination = true }
            x += layout.widths.at(row).at(ci) + component-gap
          }
        }
      }
      let coupled = layout.couplers.filter(c => c.coupled == row)
      if coupled.len() > 0 { wire-end = coupled.first().x }
      if "connect" in wire {
        assert(not has-switch, message: "A switch line cannot also end at a circulator.")
        let target = connection-point(config, layout, wire.connect)
        assert(target.row != row, message: "A line must connect to a circulator on another line.")
        let endpoint = target.point
        for (si, stage) in config.stages.enumerate() {
          let x = layout.component-starts.at(row).at(si)
          for (ci, component) in wire.at("components", default: ()).enumerate() {
            if component.stage == stage.id {
            x = layout.component-xs.at(row).at(ci)
              x += layout.widths.at(row).at(ci)
              assert(x <= endpoint.first(), message: "Connected line components must precede its endpoint.")
              x += component-gap
            }
          }
        }
        sline((wire-start, y), endpoint, stroke: wire-stroke, name: "wire-" + str(row + 1))
      } else {
        line((wire-start, y), (wire-end, y), stroke: wire-stroke, name: "wire-" + str(row + 1))
      }
      content((wire-start - 0.15, y), text(size: font-size, str(wire.at("label", default: row + 1))), anchor: "east")
      if coupled.len() == 0 and not has-switch and not has-termination and not "connect" in wire and not "termination" in wire and wire.at("port", default: none) != none {
        content((layout.end + lead + 0.15, y), text(size: font-size, str(wire.port)), anchor: "west")
      }
      for (index, stage) in config.stages.enumerate() {
        let x = layout.component-starts.at(row).at(index)
        for (ci, component) in wire.at("components", default: ()).enumerate() {
          if component.stage == stage.id {
            x = layout.component-xs.at(row).at(ci)
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
    for coupler in layout.couplers {
      draw.group(name: coupler.name, {
        directional-coupler(x: coupler.x, y: -coupler.through * line-gap, coupled-y: -coupler.coupled * line-gap,
          width: coupler.width, label: coupler.at("label", default: ""), font-size: font-size, stroke: stroke)
      })
    }
    // Terminations are drawn after all component and line anchors exist.
    for extra in extras.filter(e => type(e) == dictionary and e.at("_frigorify", default: none) == "termination") {
      let render = if extra.kind == "short" { short } else { load }
      render(extra.target, ..(font-size: font-size, ..extra.options))
    }
    // Ordinary CeTZ elements render after the fridge; callbacks use final layout.
    for extra in extras {
      if type(extra) == dictionary and extra.at("_frigorify", default: none) == "overlay" {
        (extra.callback)(layout)
      } else if not (type(extra) == dictionary and extra.at("_frigorify", default: none) == "termination") { (extra,) }
    }
  })
}
