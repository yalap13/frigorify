#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#let config = (stages: ((id: "a", label: "A"),), lines: (
  (label: "Drive", port: "Output", components: ((type: "attenuator", stage: "a", db: 20),)),
  (label: "Readout"),
))
#let check-top = {
  cetz.draw.get-ctx(ctx => {
    let (_, start) = cetz.coordinate.resolve(ctx, "wire-1.start")
    let (_, label) = cetz.coordinate.resolve(ctx, "line-label-1.south-west")
    assert(calc.abs(label.first() - start.first() - 0.15) < 1e-9)
    assert(label.at(1) > start.at(1))
    ()
  })
}
#f.fridge(config)
#f.fridge(config, line-label-font-size: 14)
#f.fridge(config, line-label-position: "top", line-label-font-size: 12pt, check-top)
#f.fridge((..config, line-label-position: "top", line-label-font-size: 12), check-top)
#f.fridge(config, line-label-position: "left", line-label-font-size: 8pt,
  style: (line-label-position: "top", line-label-font-size: 12pt), check-top)
#f.fridge(config, first-stage-side: "left", line-label-position: "top", check-top)
#f.fridge((..config, line-label-position: "top"), line-label-position: "left", {
  cetz.draw.get-ctx(ctx => {
    let (_, start) = cetz.coordinate.resolve(ctx, "wire-1.start")
    let (_, label) = cetz.coordinate.resolve(ctx, "line-label-1.east")
    assert(label.first() < start.first())
    assert(calc.abs(label.at(1) - start.at(1)) < 1e-9)
    ()
  })
})

// Long labels must fit before the first component or stage, even with no lead.
#let long-config = (..config, lines: (
  (label: "A very long drive line label", components: config.lines.first().components),
  (label: "Readout"),
))
#for side in ("left", "right") {
  for (size, unit) in ((9pt, 1cm), (18pt, 5mm)) {
    context {
      let layout = f.fridge-layout(long-config, first-stage-side: side, unit: unit)
      f.fridge(long-config, first-stage-side: side, unit: unit, lead: 0,
        line-label-position: "top", line-label-font-size: size, {
        cetz.draw.get-ctx(ctx => {
          let (_, start) = cetz.coordinate.resolve(ctx, "wire-1.start")
          let (_, left) = cetz.coordinate.resolve(ctx, "line-label-1.south-west")
          let (_, right) = cetz.coordinate.resolve(ctx, "line-label-1.south-east")
          assert(calc.abs(left.first() - start.first() - 0.15) < 1e-9)
          assert(right.first() <= -layout.left-extent - 0.15 + 1e-9)
          let expected = measure(text(size: size, long-config.lines.first().label)).width / unit + 0.3
          assert(calc.abs(-layout.left-extent - start.first() - expected) < 1e-9)
          ()
        })
      })
    }
  }
}
