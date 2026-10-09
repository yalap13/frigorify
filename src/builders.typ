#import "lines.typ": sline, zline, right-end
// These commands collect components before measuring and drawing the fridge.
/// Create a generic stage component command for a `fridge` drawing block.
/// Prefer the named builders for discoverable options. Components are collected
/// before layout, appended to existing config components, and placed in stage order.
/// -> array
#let component(
  /// Supported component type, e.g. attenuator, circulator, short, or load.
  /// -> str
  kind,
  /// Line ID, fallback label, or one-based line number; must match exactly one line.
  /// -> int | str
  line,
  /// Existing stage ID.
  /// -> str
  stage,
  /// Named component fields; positional options are rejected.
  /// -> arguments
  ..options,
) = {
  assert(options.pos() == (), message: "Component options must be named.")
  ((_frigorify: "component", line: line, component: (..options.named(), type: kind, stage: stage)),)
}
/// Add an attenuator to a line and stage from the optional `fridge` drawing block. Use as `add.attenuator`; commands are collected before layout and appended in call order.
/// -> array
#let attenuator(
  /// One-based line number, or string matching a line `id` (falling back to `label` when no ID exists). Must identify exactly one line.
  /// -> int | str
  line,
  /// ID of the stage where the component is mounted.
  /// -> str
  stage,
  /// Named component fields: `db` (default 0), `label`, `width`, `padding-x`, and `padding-y`. Padding values are nonnegative canvas units per side. Positional options are rejected.
  /// -> arguments
  ..options,
) = component("attenuator", line, stage, ..options)
/// Add an amplifier to a line and stage from the optional `fridge` drawing block. Use as `add.amplifier`; commands are collected before layout and appended in call order.
/// -> array
#let amplifier(
  /// One-based line number, or string matching a line `id` (falling back to `label` when no ID exists). Must identify exactly one line.
  /// -> int | str
  line,
  /// ID of the stage where the component is mounted.
  /// -> str
  stage,
  /// Named component fields: `gain` (string), `label`, `width`, and `direction` (`left` by default, or `right`). Positional options are rejected.
  /// -> arguments
  ..options,
) = component("amplifier", line, stage, ..options)
/// Add a circulator to a line and stage from the optional `fridge` drawing block. Use as `add.circulator`; commands are collected before layout and appended in call order.
/// -> array
#let circulator(
  /// One-based line number, or string matching a line `id` (falling back to `label` when no ID exists). Must identify exactly one line.
  /// -> int | str
  line,
  /// ID of the stage where the component is mounted.
  /// -> str
  stage,
  /// Named component fields: `junctions` (1 or 2), `label`, `width`, and `direction` (`right` or `left`). Positional options are rejected.
  /// -> arguments
  ..options,
) = component("circulator", line, stage, ..options)
/// Add a filter to a line and stage from the optional `fridge` drawing block. Use as `add.filter`; commands are collected before layout and appended in call order.
/// -> array
#let filter(
  /// One-based line number, or string matching a line `id` (falling back to `label` when no ID exists). Must identify exactly one line.
  /// -> int | str
  line,
  /// ID of the stage where the component is mounted.
  /// -> str
  stage,
  /// Named component fields: `kind` (default `LPF`), `label`, and `width`. LPF, HPF, and BPF support spelled-out names. Positional options are rejected.
  /// -> arguments
  ..options,
) = component("filter", line, stage, ..options)
// The callback receives final geometry and returns ordinary CeTZ elements.
/// Schedule a CeTZ overlay that uses final measured geometry. Use in the optional `fridge` drawing block as `add.overlay(callback)`.
/// -> array
#let overlay(
  /// Function receiving the final layout dictionary and returning an array of CeTZ drawing elements.
  /// -> function
  callback,
) = ((_frigorify: "overlay", callback: callback),)

// Convert JSON/native termination data into the same commands as block helpers.
/// Advanced config helper converting termination data to a block command.
/// Validates type, target, and accepted fields; render-time validation handles sizes.
/// -> array
#let termination-command(
  /// "short"/"load" string or dictionary with `type`, optional `target`, and symbol options.
  /// -> str | dictionary
  value,
  /// Target override: line selector or named anchor. None uses the dictionary target.
  /// -> none | int | str
  target: none,
) = {
  let spec = if type(value) == str { (type: value) } else { value }
  assert(type(spec) == dictionary and spec.at("type", default: none) in ("short", "load"),
    message: "Termination type must be short or load.")
  let target = if target == none { spec.at("target", default: none) } else { target }
  assert(type(target) in (int, str), message: "Termination target must be a line selector or named anchor.")
  assert(spec.keys().all(key => key in ("type", "target", "direction", "name", "scale", "label", "show-label", "font-size", "stroke")),
    message: "Unknown JSON termination option.")
  let options = spec
  let _ = options.remove("type")
  let _ = options.remove("target", default: none)
  ((_frigorify: "termination", kind: spec.type, target: target, options: options),)
}

/// Advanced helper combining config and block commands without modifying the input.
/// Returns `(config, extras)`: updated lines and drawing elements/overlay/termination
/// descriptors. It also translates JSON endpoint and top-level port terminations.
/// `fridge` normally calls this automatically; it does not perform label measurement.
/// -> array
#let assemble(
  /// Fridge configuration dictionary with stages and lines.
  /// -> dictionary
  config,
  /// Array of component, connect, termination, overlay commands and CeTZ elements.
  /// -> array
  body,
) = {
  assert(type(body) == array, message: "Fridge body must produce component commands or CeTZ elements.")
  let lines = config.lines
  let couplers = config.at("couplers", default: ())
  let extras = ()
  let configured = ()
  for (index, wire) in lines.enumerate() {
    if "termination" in wire {
      let value = wire.remove("termination")
      lines.at(index) = wire
      configured += termination-command(value, target: index + 1)
    }
  }
  let terminations = config.at("terminations", default: ())
  assert(type(terminations) == array, message: "terminations must be an array.")
  for value in terminations { configured += termination-command(value) }
  for item in configured + body {
    if type(item) == dictionary and item.at("_frigorify", default: none) == "termination" {
      if type(item.target) == int or (type(item.target) == str and not item.target.contains(".")) {
        let matches = lines.enumerate().filter(pair => {
          if type(item.target) == int { pair.first() + 1 == item.target }
          else { pair.last().at("id", default: pair.last().at("label", default: none)) == item.target }
        })
        assert(matches.len() == 1, message: "Termination line must identify exactly one line.")
        let index = matches.first().first()
        let wire = lines.at(index)
        assert(not "termination" in wire and not "connect" in wire and
          not wire.at("components", default: ()).any(c => c.type == "rf-switch"),
          message: "A terminated line cannot have another endpoint termination, connection, or switch.")
        wire.insert("termination", item.kind)
        lines.at(index) = wire
        extras.push((..item, target: "wire-" + str(index + 1) + ".end"))
      } else { extras.push(item) }
    } else if type(item) == dictionary and item.at("_frigorify", default: none) == "coupler" {
      let c = item.coupler
      let matches(value) = lines.enumerate().filter(pair => if type(value) == int { pair.first() + 1 == value }
        else { pair.last().at("id", default: pair.last().at("label", default: none)) == value })
      for (selector, key) in ((c.through, "through-position"),) {
        let selected = matches(selector)
        assert(selected.len() == 1, message: "Coupler line must identify exactly one line.")
        if not key in c { c.insert(key, selected.first().last().at("components", default: ()).filter(component => component.stage == c.stage).len() + 1) }
      }
      couplers.push(c)
    } else if type(item) == dictionary and item.at("_frigorify", default: none) in ("component", "connect") {
      let matches = lines
        .enumerate()
        .filter(pair => {
          let (index, line) = pair
          if type(item.line) == int { index + 1 == item.line } else {
            line.at("id", default: line.at("label", default: none)) == item.line
          }
        })
      assert(matches.len() == 1, message: "Component line must identify exactly one line: " + repr(item.line))
      let index = matches.first().first()
      let line = lines.at(index)
      if item._frigorify == "component" {
        line.insert("components", line.at("components", default: ()) + (item.component,))
      } else {
        assert(not "connect" in line, message: "A line can have only one endpoint connection.")
        line.insert("connect", item.target)
      }
      lines.at(index) = line
    } else { extras.push(item) }
  }
  for wire in lines {
    if "termination" in wire {
      assert(not "connect" in wire and not wire.at("components", default: ()).any(c => c.type == "rf-switch"),
        message: "A terminated line cannot have another endpoint termination, connection, or switch.")
    }
  }
  ((..config, lines: lines, couplers: couplers), extras)
}

/// Add a six-way RF switch. The selected line ends at its center common port.
/// Must be the final component in physical stage order; the right endpoint label is omitted.
/// Connect outer ports using `component-N-M.port-1` through `port-6` in the drawing block.
/// -> array
#let rf-switch(
  /// line ID, label, or one-based number.
  /// -> int | str
  line,
  /// Mounting stage ID. The switch must be the final component along the line.
  /// -> str
  stage,
  /// Optional `label` and minimum `width`.
  /// -> arguments
  ..options,
) = component("rf-switch", line, stage, ..options)

/// End a fridge line at a circulator port, routing horizontally then vertically.
/// The usual right endpoint and its label are replaced by this connection.
/// Target must be a circulator on another line. Supports forward references to
/// components added later in the block. Source components must fit before the bend.
/// A source line cannot also end at a switch or ground termination. Color and stroke
/// follow the source line; routing does not avoid obstacles automatically.
/// -> array
#let connect(
  /// Line ID, label, or one-based number.
  /// -> int | str
  line,
  /// Circulator anchor, e.g. `component-2-1.port-3-top`.
  /// -> str
  to: none,
) = {
  assert(type(to) == str, message: "Connection target must be a circulator anchor string.")
  ((_frigorify: "connect", line: line, target: to),)
}

/// Advanced helper selecting stage placement or endpoint/port attachment for a termination.
/// Prefer `add.short` and `add.load`. A positional stage or named `stage` makes a
/// component command; omitting stage makes an endpoint/port termination descriptor.
/// -> array
#let terminate(
  /// "short" or "load".
  /// -> str
  kind,
  /// Line selector (with/without stage), or named port (without stage).
  /// -> int | str
  target,
  /// Arguments with optional stage and named termination options.
  /// -> arguments
  options,
) = {
  assert(options.pos().len() <= 1, message: "Termination accepts at most one stage argument.")
  let fields = options.named()
  let stage = fields.remove("stage", default: none)
  if options.pos().len() == 1 {
    assert(stage == none, message: "Specify termination stage only once.")
    stage = options.pos().first()
  }
  if stage != none { component(kind, target, stage, ..fields) }
  else { ((_frigorify: "termination", kind: kind, target: target, options: fields),) }
}

/// Short a fridge line to ground at a stage: `add.short(line, stage)`.
/// Without a stage, attach at a line endpoint or named component port.
/// Stage components must be final in physical stage order. Endpoint attachments omit
/// the right port label. Cannot share a line endpoint with a switch or `connect`.
/// With a stage, use a line selector; without a stage, a string containing a dot
/// is treated as a CeTZ anchor. Anchors may be declared later in the drawing block.
/// -> array
#let short(
  /// Line ID/label/one-based number, or a CeTZ port anchor containing a dot.
  /// -> int | str
  target,
  /// Optional positional stage (or named `stage`), `direction` (default down), `scale`
  /// (default 0.65), `label`, `show-label` (default true), `font-size`, and `stroke`.
  /// Stage components accept minimum `width`; endpoint/port symbols accept `name`.
  /// Numeric font sizes and stroke thicknesses are points, or use Typst lengths.
  /// -> arguments
  ..options,
) = terminate("short", target, options)

/// Add a 50 Ω ground termination at a stage: `add.load(line, stage)`.
/// Without a stage, attach at a line endpoint or named component port.
/// Stage components must be final in physical stage order. Endpoint attachments omit
/// the right port label. Cannot share a line endpoint with a switch or `connect`.
/// With a stage, use a line selector; without a stage, a string containing a dot
/// is treated as a CeTZ anchor. Anchors may be declared later in the drawing block.
/// -> array
#let load(
  /// Line ID/label/one-based number, or a CeTZ port anchor containing a dot.
  /// -> int | str
  target,
  /// Optional positional stage (or named `stage`), `direction` (default down), `scale`
  /// (default 0.65), `label` (default "50 Ω"), `show-label` (default true), `font-size`,
  /// and `stroke`. False/none/empty label hides it. Stage components accept minimum
  /// `width`; endpoint/port symbols accept `name`. Numeric font/stroke values are points.
  /// -> arguments
  ..options,
) = terminate("load", target, options)

/// Add a three-port directional coupler between adjacent fridge lines.
/// The through line continues; the coupled line ends at its curved input.
/// Call order inserts the coupler in the through line before later additions. The
/// coupled input follows all its stage components, including later block additions.
/// Explicit through-position/coupled-position override
/// these one-based insertion slots. Exposes named main-in/main-out/coupled anchors.
/// -> array
#let directional-coupler(
  /// Through line ID, label, or one-based number.
  /// -> int | str
  through,
  /// Coupled line ID, label, or one-based number; must be adjacent to through.
  /// -> int | str
  coupled,
  /// Existing mounting stage ID.
  /// -> str
  stage,
  /// Named width (default 0.9, expanded to fit label), label (empty), name (coupler-N),
  /// through-position and coupled-position (one-based stage component insertion slots).
  /// -> arguments
  ..options,
) = {
  assert(options.pos() == (), message: "Coupler options must be named.")
  ((_frigorify: "coupler", coupler: (..options.named(), through: through, coupled: coupled, stage: stage)),)
}

/// End a fridge line with an open not-connected bracket at a stage.
/// Must be the final component in physical stage order; omits the right endpoint label.
/// -> array
#let not-connected(
  /// Line ID, fallback label, or one-based number.
  /// -> int | str
  line,
  /// Existing mounting stage ID.
  /// -> str
  stage,
  /// Named scale (0.65), direction (right/left), label (empty), show-label (true),
  /// font-size, stroke, and minimum width. Numeric font/stroke values are points.
  /// -> arguments
  ..options,
) = component("not-connected", line, stage, ..options)
