#import "../src/frigorify.typ" as f
#import "../src/components.typ": component-font-size
#import "@preview/cetz:0.5.2": canvas
#set page(width: auto, height: auto)
#assert.eq(component-font-size((font-size: 12)), 12pt)
#assert.eq(component-font-size((font-size: 7pt), default: 20pt), 7pt)
#assert.eq(component-font-size((:), default: 10pt), 10pt)
#context {
  let config = (stages: ((id: "a", label: "A"),), lines: ((id: "line", components: ()),))
  for kind in ("attenuator", "amplifier", "circulator", "filter", "rf-switch", "short", "load", "not-connected") {
    let fixed = (..config, lines: ((components: ((type: kind, stage: "a", label: "Long component label", font-size: 18),)),))
    let small = f.fridge-layout(fixed, font-size: 6pt)
    let large = f.fridge-layout(fixed, font-size: 24pt)
    assert.eq(small.widths, large.widths)
    assert.eq(small.heights, large.heights)
    let inherited = (..config, lines: ((components: ((type: kind, stage: "a", label: "Long component label"),)),))
    assert(f.fridge-layout(inherited, font-size: 6pt).widths.first().first() < small.widths.first().first())
    f.fridge(fixed, font-size: 6pt)
    canvas({ f.fridge-component(fixed.lines.first().components.first(), width: small.widths.first().first(), font-size: 6pt) })
  }
  f.fridge(config, font-size: 6pt, {
    f.add.attenuator("line", "a", db: 20, font-size: 16pt)
    f.add.filter("line", "a", label: "Small", font-size: 7pt)
  })
}
