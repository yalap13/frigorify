#import "../src/frigorify.typ" as f
#import "../src/components.typ": component-label
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#assert.eq(component-label((type: "load", label: false)), "")
#assert.eq(component-label((type: "load", label: none)), "")
#assert.eq(component-label((type: "load", show-label: false)), "")
#assert.eq(component-label((type: "load", label: "Matched")), "Matched")
#let config = (stages: ((id: "mix", label: "Mix"),), lines: ((id: "a", components: ((type: "load", stage: "mix", scale: 0.5, show-label: false, font-size: 7, stroke: 0.4),)),))
#context {
  let small = f.fridge-layout(config)
  let labelled = f.fridge-layout((..config, lines: ((components: ((type: "load", stage: "mix", label: "Matched termination"),)),)))
  assert(small.widths.first().first() < labelled.widths.first().first())
}
#f.fridge(config)
#f.fridge((stages: config.stages, lines: ((id: "a",),)), {
  f.add.load("a", "mix", scale: 0.5, label: false, stroke: 0.4, font-size: 7)
})
#f.fridge((stages: config.stages, lines: ((id: "a", termination: (type: "load", scale: 0.5, label: false, name: "small", stroke: 0.4, font-size: 7)),)), {
  cetz.draw.get-ctx(ctx => {
    let (_, input) = cetz.coordinate.resolve(ctx, "small.in")
    let (_, ground) = cetz.coordinate.resolve(ctx, "small.ground")
    assert(calc.abs(input.at(1) - ground.at(1) - 0.32) < 1e-9)
    ()
  })
})
#f.fridge((stages: config.stages, lines: ((id: "a",),), terminations: ((type: "load", target: "a", scale: 0.5, label: "Matched", stroke: 0.4, font-size: 7),)))
