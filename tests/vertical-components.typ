#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#cetz.canvas({
  for (index, kind) in ("attenuator", "amplifier", "circulator", "filter", "rf-switch", "short", "load", "not-connected").enumerate() {
    f.fridge-component((type: kind, label: kind, font-size: 8), x: index * 2, y: 0,
      orientation: "vertical")
  }
  cetz.draw.group(name: "vertical", {
    f.fridge-component((type: "circulator", junctions: 2), x: 3, y: -3, orientation: "vertical")
  })
  cetz.draw.line((0, -5), (1, -5), name: "after")
  cetz.draw.get-ctx(ctx => {
    for (anchor, expected) in (("vertical.in", (3, -3)), ("vertical.out", (3, -1.92)),
      ("vertical.port-3-bottom", (3.27, -2.73)), ("after.end", (1, -5))) {
      let (_, point) = cetz.coordinate.resolve(ctx, anchor)
      for axis in range(2) { assert(calc.abs(point.at(axis) - expected.at(axis)) < 1e-9) }
    }
    ()
  })
})
