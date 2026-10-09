#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#f.fridge((stages: ((id: "a", label: "A"),), lines: ((label: "1", components: ((type: "circulator", stage: "a"),)),)),
  lead: 0.1, style: (lead: 1.2), {
  f.sline("component-1-1.port-3", f.right-end(-1), name: "extra")
  f.zline("component-1-1.port-3", f.add.right-end("component-1-1.port-3"), name: "same-height")
  cetz.draw.line((0, -2), f.right-end(-2), name: "plain")
  cetz.draw.get-ctx(ctx => {
    let (_, base) = cetz.coordinate.resolve(ctx, "wire-1.end")
    for (name, y) in (("extra", -1), ("same-height", -0.27), ("plain", -2)) {
      let (_, endpoint) = cetz.coordinate.resolve(ctx, name + ".end")
      assert(calc.abs(endpoint.first() - base.first()) < 1e-9)
      assert(calc.abs(endpoint.at(1) - y) < 1e-9)
    }
    ()
  })
})
