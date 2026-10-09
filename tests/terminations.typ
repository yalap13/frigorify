#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#let config = (stages: ((id: "a", label: "A"),), lines: ((id: "one", port: "Old label"), (id: "two",), (id: "circ",)))
#let commands = {
  f.add.short("one", name: "end-short")
  f.add.load(2, name: "end-load", stroke: 0.4pt)
  f.add.short("component-3-1.port-3-top", direction: "up", name: "port-short")
  f.add.load("component-3-1.port-4-bottom", name: "port-load")
  f.add.circulator("circ", "a", junctions: 2)
}
#let (assembled, _) = f.add.assemble(config, commands)
#assert(not "termination" in config.lines.first())
#assert.eq(assembled.lines.first().termination, "short")
#assert.eq(assembled.lines.at(1).termination, "load")
#f.fridge(config, line-gap: 1.5, stroke: 1.3pt, {
  commands
  cetz.draw.get-ctx(ctx => {
    for (termination, target) in (("end-short", "wire-1.end"), ("end-load", "wire-2.end"),
        ("port-short", "component-3-1.port-3-top"), ("port-load", "component-3-1.port-4-bottom")) {
      let (_, a) = cetz.coordinate.resolve(ctx, termination + ".in")
      let (_, b) = cetz.coordinate.resolve(ctx, target)
      for axis in range(3) { assert(calc.abs(a.at(axis) - b.at(axis)) < 1e-9) }
    }
    ()
  })
})
#cetz.canvas({
  for (i, direction) in ("up", "down", "left", "right").enumerate() {
    f.short((i * 2, 0), direction: direction)
    f.load((i * 2, -2), direction: direction)
  }
})
