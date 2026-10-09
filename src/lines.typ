#import "@preview/cetz:0.5.2" as cetz

// Resolve coordinates at draw time, after component and stage anchors exist.
/// Advanced routing helper returning planar orthogonal vertices without drawing.
/// Resolves CeTZ coordinates in ctx and applies the route to each consecutive pair.
/// Adjacent repeated vertices are removed; a zero-length route keeps two vertices.
/// Z coordinates are discarded because Frigorify routing is two-dimensional.
/// -> array
#let route-points(
  /// CeTZ draw context, obtained inside `draw.get-ctx`.
  /// -> dictionary
  ctx,
  /// At least two CeTZ coordinates, including named anchors.
  /// -> array
  points,
  /// x for horizontal–vertical–horizontal, y for vertical–horizontal–vertical.
  /// -> str
  axis,
  /// CeTZ interpolation position: percentage, numeric distance, or physical length.
  /// -> ratio | int | float | length
  ratio,
) = {
  let (ctx, ..nodes) = cetz.coordinate.resolve(ctx, ..points)
  let nodes = nodes.map(point => point.slice(0, 2))
  let routed = ()
  for (a, b) in nodes.zip(nodes.slice(1)) {
    let (ctx, mid) = cetz.coordinate.resolve(ctx, (a, ratio, b))
    let bends = if axis == "x" {
      ((mid.at(0), a.at(1)), (mid.at(0), b.at(1)))
    } else {
      ((a.at(0), mid.at(1)), (b.at(0), mid.at(1)))
    }
    for point in (a, ..bends, b) {
      if routed.len() == 0 or routed.last() != point { routed.push(point) }
    }
  }
  // CeTZ needs two points even for a zero-length connection.
  if routed.len() == 1 { routed.push(routed.first()) }
  routed
}

/// Draw orthogonal three-segment connections.
/// Accepts CeTZ coordinates, including component ports and stage/line anchors.
/// For each consecutive pair, `axis: "x"` makes horizontal–vertical–horizontal segments;
/// `axis: "y"` makes vertical–horizontal–vertical segments. Use in a fridge block or CeTZ canvas.
/// Also available as `add.zline`. Inherits the fridge's line stroke unless explicitly
/// overridden. With `name`, exposes CeTZ line/path anchors such as `start`, `end`, and
/// `50%`. Routing is planar and does not avoid symbols or other lines automatically.
/// -> array
#let zline(
  /// Axis along which the middle segment is positioned: `x` or `y`.
  /// -> str
  axis: "x",
  /// Bend position between endpoints. Percentages interpolate; numbers and lengths
  /// are distances from the start along the endpoint-to-endpoint vector, as in CeTZ.
  /// -> ratio | int | float | length
  ratio: 50%,
  /// Two or more positional CeTZ coordinates and named CeTZ line styling options
  /// such as `stroke`, `name`, or `mark`.
  /// -> arguments
  ..points-style,
) = {
  assert(axis in ("x", "y"), message: "Line axis must be x or y.")
  assert(type(ratio) in (type(50%), int, float, length), message: "Line ratio must be a percentage, number, or length.")
  assert(points-style.pos().len() >= 2, message: "Routed lines need at least two coordinates.")
  cetz.draw.get-ctx(ctx => {
    let points = route-points(ctx, points-style.pos(), axis, ratio)
    cetz.draw.line(..points, ..points-style.named())
  })
}

/// Draw a single-bend orthogonal connection.
/// `axis: "x"` (default) goes horizontally then vertically; `axis: "y"` goes
/// vertically then horizontally. Works with named component ports and CeTZ coordinates.
/// Also available as `add.sline`. Equivalent to `zline(..., ratio: 100%)`; applies
/// to every consecutive pair. Inherits the fridge line stroke and forwards line styles.
/// With `name`, exposes normal CeTZ path anchors. No automatic obstacle avoidance.
/// -> array
#let sline(
  /// Initial segment axis: `x` or `y`.
  /// -> str
  axis: "x",
  /// Two or more positional CeTZ coordinates and named CeTZ line styling options.
  /// -> arguments
  ..points-style,
) = zline(axis: axis, ratio: 100%, ..points-style)

/// Return a CeTZ coordinate at the fridge's normal right endpoint x (layout.end + lead).
/// Use with draw.line, sline, zline, or content in a fridge drawing block. Numeric
/// input selects a canvas y; a CeTZ coordinate/anchor supplies its y. Resolution is
/// deferred until drawing, so style lead overrides and automatic layout are respected.
/// Also available as add.right-end. The right edge is the diagram endpoint position,
/// even if individual lines end earlier at terminations, switches, or couplers.
/// -> dictionary
#let right-end(
  /// Y in canvas units, or a CeTZ coordinate/anchor whose y should be reused.
  /// -> int | float | array | str | dictionary
  y,
) = (horizontal: "fridge-right", vertical: if type(y) in (int, float) { (0, y) } else { y })
