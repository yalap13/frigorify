#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#let config = (stages: ((id: "a", label: "A"), (id: "b", label: "B")), lines: ((id: "main",), (id: "coupled",)))
#for side in ("left", "right") {
  f.fridge(config, first-stage-side: side, {
    f.add.attenuator("main", "a", db: 3)
    f.add.directional-coupler("main", 2, "a", name: "dc")
    f.add.filter("main", "a", kind: "LPF")
    f.add.attenuator("coupled", "a", db: 10)
    cetz.draw.get-ctx(ctx => {
      let (_, wire) = cetz.coordinate.resolve(ctx, "wire-2.end")
      let (_, port) = cetz.coordinate.resolve(ctx, "dc.coupled")
      for axis in range(3) { assert(calc.abs(wire.at(axis) - port.at(axis)) < 1e-9) }
      let (_, out) = cetz.coordinate.resolve(ctx, "dc.main-out")
      let (_, edge) = cetz.coordinate.resolve(ctx, "component-1-1.east")
      assert(edge.first() < port.first())
      let (_, lower) = cetz.coordinate.resolve(ctx, "component-2-1.east")
      assert(lower.first() < port.first())
      let (_, filter) = cetz.coordinate.resolve(ctx, "component-1-2.west")
      assert(filter.first() > out.first())
      if side == "left" { assert(filter.first() < 0) }
      ()
    })
  })
}
#f.fridge((..config, couplers: ((through: "main", coupled: "coupled", stage: "b"),)))
#cetz.canvas({
  cetz.draw.group(name: "amp", { f.amplifier((type: "amplifier")) })
  cetz.draw.get-ctx(ctx => {
    // Default-left triangle has its west tip at y=0.
    let (_, west) = cetz.coordinate.resolve(ctx, "amp.west")
    assert(calc.abs(west.at(1)) < 1e-9)
    ()
  })
})

#context {
  let configured = (..config, lines: ((id: "main", components: ((type: "attenuator", stage: "a", db: 3), (type: "filter", stage: "a"))), (id: "coupled",)),
    couplers: ((through: "main", coupled: "coupled", stage: "a", through-position: 2, coupled-position: 1),))
  let layout = f.fridge-layout(configured)
  assert(layout.component-xs.first().first() < layout.couplers.first().x)
  assert(layout.component-xs.first().last() > layout.couplers.first().x + layout.couplers.first().width)
}
