#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#let base = (stages: ((id: "mix", label: "Mix"),), lines: ((id: "upper",), (id: "output",), (id: "lower",)))
#let commands = {
  f.add.connect("upper", to: "component-2-1.port-3-top")
  f.add.connect(3, to: "component-2-1.port-4-bottom")
  f.add.circulator("output", "mix", junctions: 2)
}
#let (config, _) = f.add.assemble(base, commands)
#assert(not "connect" in base.lines.first())
#context {
  let layout = f.fridge-layout(config)
  let top = f.connection-point(config, layout, config.lines.first().connect)
  let bottom = f.connection-point(config, layout, config.lines.last().connect)
  assert.eq(top.point, (0.27, -0.85 + 0.27))
  assert.eq(bottom.point, (0.81, -0.85 - 0.27))
  assert.eq(top.row, 1)
}
#f.fridge(base, {
  commands
  cetz.draw.get-ctx(ctx => {
    for (wire, port) in (("wire-1", "component-2-1.port-3-top"), ("wire-3", "component-2-1.port-4-bottom")) {
      let (_, end) = cetz.coordinate.resolve(ctx, wire + ".end")
      let (_, target) = cetz.coordinate.resolve(ctx, port)
      for axis in range(3) { assert(calc.abs(end.at(axis) - target.at(axis)) < 1e-9) }
    }
    ()
  })
})
