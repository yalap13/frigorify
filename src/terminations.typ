#import "@preview/cetz:0.5.2" as cetz

// JSON numbers for physical styles are points; native Typst lengths also work.
/// Advanced helper validating symbol scale, label visibility, and label type.
/// Converts numeric `font-size` and `stroke` values to points, leaving Typst lengths
/// and other line styles intact. Does not render or modify the input dictionary.
/// -> dictionary
#let termination-options(
  /// Termination field dictionary. Defaults: scale 0.65, show-label true.
  /// -> dictionary
  options,
) = {
  let options = options
  let scale = options.at("scale", default: 0.65)
  assert(type(scale) in (int, float) and scale > 0, message: "Termination scale must be a positive number.")
  assert(type(options.at("show-label", default: true)) == bool, message: "Termination show-label must be boolean.")
  let label = options.at("label", default: none)
  assert(label == none or label == false or type(label) == str, message: "Termination label must be a string, false, or null.")
  for key in ("font-size", "stroke") {
    if key in options and type(options.at(key)) in (int, float) {
      assert(options.at(key) > 0, message: "Termination font-size and stroke must be positive.")
      options.insert(key, options.at(key) * 1pt)
    }
  }
  options
}

/// Advanced helper resolving a termination label. False/none/empty label or
/// `show-label: false` hides it. Otherwise defaults to "50 Ω" for loads and empty for shorts.
/// -> str
#let termination-label(
  /// Termination field dictionary.
  /// -> dictionary
  options,
  /// True selects the load's default label; false selects the short's.
  /// -> bool
  load: true,
) = {
  if not options.at("show-label", default: true) { "" }
  else {
    let label = options.at("label", default: if load { "50 Ω" } else { "" })
    if label == none or label == false { "" } else { label }
  }
}

/// Advanced common renderer for standalone short/load symbols; prefer `short` or `load`.
/// Geometry scales about the input independently of font size and stroke thickness.
/// Ground uses three decreasing bars; loads use a rectangular resistor before ground.
/// -> array
#let termination(
  /// CeTZ input coordinate or named anchor.
  /// -> array | str | dictionary
  at,
  /// True draws a 50 Ω load, false a direct short.
  /// -> bool
  load,
  /// Direction from input toward ground (down/up/left/right).
  /// -> str
  direction,
  /// Optional named group exposing in/ground anchors.
  /// -> none | str
  name,
  /// Named symbol options and CeTZ line styles.
  /// -> arguments
  options,
) = {
  assert(direction in ("down", "up", "left", "right"), message: "Termination direction must be down, up, left, or right.")
  assert(options.pos() == (), message: "Termination options must be named.")
  let style = termination-options(options.named())
  let scale = style.remove("scale", default: 0.65)
  let label = termination-label(style, load: load)
  let _ = style.remove("label", default: none)
  let _ = style.remove("show-label", default: true)
  let font-size = style.remove("font-size", default: 9pt)
  cetz.draw.group(name: name, {
    cetz.draw.get-ctx(ctx => {
      let (_, origin) = cetz.coordinate.resolve(ctx, at)
      let vector = (down: (0, -1), up: (0, 1), left: (-1, 0), right: (1, 0)).at(direction)
      let normal = (-vector.at(1), vector.at(0))
      let point(distance, side: 0) = (origin.at(0) + scale * (distance * vector.at(0) + side * normal.at(0)),
        origin.at(1) + scale * (distance * vector.at(1) + side * normal.at(1)))
      cetz.draw.anchor("in", point(0))
      if load {
        cetz.draw.line(point(0), point(0.14), ..style)
        cetz.draw.line(point(0.14, side: -0.08), point(0.14, side: 0.08),
          point(0.48, side: 0.08), point(0.48, side: -0.08), close: true, fill: white, ..style)

      }
      if label != "" {
        cetz.draw.content(point(if load { 0.31 } else { 0.125 }, side: 0.13), text(size: font-size, label),
          anchor: (down: "west", up: "east", left: "north", right: "south").at(direction))
      }
      let ground = if load { 0.64 } else { 0.25 }
      cetz.draw.line(point(if load { 0.48 } else { 0 }), point(ground), ..style)
      for (offset, half-width) in ((0, 0.18), (0.07, 0.12), (0.14, 0.06)) {
        cetz.draw.line(point(ground + offset, side: -half-width), point(ground + offset, side: half-width), ..style)
      }
      cetz.draw.anchor("ground", point(ground))
    })
  })
}

/// Draw a short to ground at a CeTZ coordinate or named port. Inherits the fridge line stroke.
/// This main-module function draws at a coordinate; `add.short(line, stage)` instead
/// mounts a component and terminates its line. Default geometry is 65% of the original:
/// input-to-ground distance 0.1625 canvas units, widest ground bar 0.234 units.
/// Named groups expose `in` and `ground`. Labels are optional and empty by default.
/// -> array
#let short(
  /// Connection coordinate or anchor.
  /// -> array | str | dictionary
  at,
  /// Direction from the connection to ground: down, up, left, or right.
  /// -> str
  direction: "down",
  /// Optional group name exposing `in` and `ground` anchors.
  /// -> none | str
  name: none,
  /// Options: `scale` (default 0.65), `label`, `show-label`, `font-size`, and line styles.
  /// Numeric font sizes and stroke thicknesses are points.
  /// -> arguments
  ..options,
) = termination(at, false, direction, name, options)

/// Draw a 50 Ω resistor to ground at a CeTZ coordinate or named port. Inherits the fridge line stroke.
/// This main-module function draws at a coordinate; `add.load(line, stage)` mounts
/// a component and terminates its line. Default scale is 0.65: resistor length 0.221,
/// width 0.104, and input-to-ground distance 0.416 canvas units. Scale does not change
/// font size or stroke thickness. Named groups expose `in` and `ground`.
/// -> array
#let load(
  /// Connection coordinate or anchor.
  /// -> array | str | dictionary
  at,
  /// Direction from the connection to ground: down, up, left, or right.
  /// -> str
  direction: "down",
  /// Optional group name exposing `in` and `ground` anchors.
  /// -> none | str
  name: none,
  /// Options: `scale` (default 0.65), `label` (default "50 Ω"; false/none hides it),
  /// `show-label` (default true), `font-size` (default 9pt), and line styles.
  /// Numeric font sizes and stroke thicknesses are points.
  /// -> arguments
  ..options,
) = termination(at, true, direction, name, options)
