#import "@preview/cetz:0.5.2": draw

/// Draw a three-port directional coupler matching a straight through path and a curved
/// coupled input. Use in a CeTZ canvas, normally inside a named group. The main line
/// continues left-to-right; the second line ends at `coupled`. All distances are canvas units.
/// -> array
#let directional-coupler(
  /// Symbol left edge.
  /// -> int | float
  x: 0,
  /// Main through-line height.
  /// -> int | float
  y: 0,
  /// Coupled input height; must differ from y. Defaults to a lower input.
  /// -> int | float
  coupled-y: -0.85,
  /// Symbol width, positive.
  /// -> int | float
  width: 0.9,
  /// Optional text above the box.
  /// -> str
  label: "",
  /// Label font size.
  /// -> length
  font-size: 9pt,
  /// Outline and internal paths thickness.
  /// -> length
  stroke: 0.7pt,
) = {
  assert(width > 0 and y != coupled-y, message: "Coupler needs positive width and distinct line heights.")
  let sign = if coupled-y < y { -1 } else { 1 }
  draw.rect((x, calc.min(y, coupled-y) - 0.12), (x + width, calc.max(y, coupled-y) + 0.12), fill: white, stroke: stroke)
  draw.line((x, y), (x + width, y), stroke: stroke)
  draw.bezier((x, coupled-y), (x + width * 0.65, y + sign * 0.12),
    (x + width * 0.45, coupled-y), (x + width * 0.15, y + sign * 0.12), stroke: stroke)
  draw.line((x + width * 0.65, y + sign * 0.12), (x + width, y + sign * 0.12), stroke: stroke)
  draw.anchor("main-in", (x, y))
  draw.anchor("main-out", (x + width, y))
  draw.anchor("coupled", (x, coupled-y))
  if label != "" { draw.content((x + width / 2, calc.max(y, coupled-y) + 0.3), text(size: font-size, label)) }
}

/// Resolve config couplers to line/stage indices without measuring or drawing.
/// Each descriptor requires through, coupled, and stage; lines must be adjacent.
/// Optional through-position/coupled-position are one-based stage-local insertion slots;
/// omitted positions append after the stage's components. Coupled lines must not have
/// another endpoint or components after their insertion slot.
/// -> array
#let resolve-couplers(
  /// Final fridge configuration with optional top-level couplers array.
  /// -> dictionary
  config,
) = {
  let entries = config.at("couplers", default: ())
  assert(type(entries) == array, message: "couplers must be an array.")
  let ended = ()
  let resolved = ()
  for c in entries {
    assert(type(c) == dictionary and ("through", "coupled", "stage").all(k => k in c), message: "Coupler requires through, coupled, and stage.")
    let select(value) = {
      let matches = config.lines.enumerate().filter(pair => if type(value) == int { pair.first() + 1 == value }
        else { pair.last().at("id", default: pair.last().at("label", default: none)) == value })
      assert(matches.len() == 1, message: "Coupler line must identify exactly one line.")
      matches.first().first()
    }
    let through = select(c.through)
    let coupled = select(c.coupled)
    assert(calc.abs(through - coupled) == 1, message: "Coupler lines must be adjacent.")
    let stage = config.stages.position(s => s.id == c.stage)
    assert(stage != none, message: "Unknown coupler stage.")
    assert(not coupled in ended, message: "A coupled line can end at only one coupler.")
    ended.push(coupled)
    let positions = (:)
    for (row, key) in ((through, "through-position"), (coupled, "coupled-position")) {
      let count = config.lines.at(row).at("components", default: ()).filter(component => component.stage == c.stage).len()
      let slot = c.at(key, default: count + 1)
      assert(type(slot) == int and slot >= 1 and slot <= count + 1, message: "Coupler position must be a valid one-based stage slot.")
      positions.insert(key, slot)
      if row == coupled { assert(slot == count + 1, message: "Coupled line cannot have components after its coupler.") }
    }
    let wire = config.lines.at(coupled)
    assert(not "connect" in wire and not "termination" in wire and wire.at("components", default: ()).all(component =>
      not component.type in ("short", "load", "not-connected", "rf-switch") and config.stages.position(s => s.id == component.stage) <= stage),
      message: "Coupled line cannot continue after its coupler or have another endpoint.")
    let main = config.lines.at(through)
    assert(not "connect" in main and not "termination" in main and main.at("components", default: ()).all(component =>
      not component.type in ("short", "load", "not-connected", "rf-switch") or config.stages.position(s => s.id == component.stage) > stage),
      message: "Through line must continue through its coupler.")
    assert(type(c.at("width", default: 0.9)) in (int, float) and c.at("width", default: 0.9) > 0, message: "Coupler width must be positive.")
    assert(type(c.at("name", default: "coupler")) == str and c.at("name", default: "coupler") != "", message: "Coupler name must be a nonempty string.")
    assert(type(c.at("label", default: "")) == str, message: "Coupler label must be a string.")
    resolved.push((..c, ..positions, through: through, coupled: coupled, stage: stage))
  }
  for c in resolved {
    assert(not resolved.any(other => other.coupled == c.through and other.stage <= c.stage), message: "Through line must continue through its coupler.")
  }
  resolved
}
