#import "../src/frigorify.typ": fridge-layout, fridge, add
#set page(width: auto, height: auto)
#context {
  let empty = (stages: ((id: "a", label: "A"), (id: "b", label: "B")), lines: ((label: "1",),))
  let base = fridge-layout(empty)
  assert.eq(base.stages, (0, 1.6))
  assert.eq(base.end, 3.2)
  let busy = (stages: empty.stages, lines: (
    (components: ((type: "attenuator", stage: "a", db: 10), (type: "attenuator", stage: "a", db: 20))),
    (components: ((type: "filter", stage: "b", label: "An unusually long filter label"),)),
  ))
  let layout = fridge-layout(busy)
  assert(layout.gaps.first() > base.gaps.first(), message: "Component chains must expand an interval.")
  assert(layout.gaps.at(1) > base.gaps.at(1), message: "Measured labels must expand an interval.")
  assert.eq(layout.stages.at(1), layout.gaps.first())
  assert.eq(layout.end, layout.gaps.sum())
  for (row, wire) in busy.lines.enumerate() {
    for (index, stage) in busy.stages.enumerate() {
      let widths = wire.components.enumerate().filter(pair => pair.at(1).stage == stage.id)
        .map(pair => layout.widths.at(row).at(pair.at(0)))
      let used = widths.sum(default: 0) + calc.max(0, widths.len() - 1) * layout.component-gap
      assert(used + layout.stage-padding <= layout.gaps.at(index) + 1e-9)
    }
  }
  let amplifier-chain = (stages: empty.stages, lines: ((components: (
    (type: "amplifier", stage: "a"), (type: "attenuator", stage: "a", db: 3),
  )),))
  let amplifier-layout = fridge-layout(amplifier-chain, component-gap: 0.01)
  assert.eq(amplifier-layout.widths.first().first(), calc.sqrt(3) * 0.24)
  let wide-amplifier = (stages: empty.stages, lines: ((components: (
    (type: "amplifier", stage: "a", width: 1),
  )),))
  assert.eq(fridge-layout(wide-amplifier).widths.first().first(), 1)
  let labelled-amplifier = (stages: empty.stages, lines: ((components: (
    (type: "amplifier", stage: "a", gain: "A long amplifier label"),
  )),))
  assert(fridge-layout(labelled-amplifier).widths.first().first() > amplifier-layout.widths.first().first())
  let single = (stages: ((id: "mix", label: "10 mK"),), lines: ((components: ()),))
  assert.eq(fridge-layout(single).stages, (0,))
  // Additions append to JSON components without changing the initial config.
  let commands = {
    add.attenuator(1, "a", db: 3)
    add.circulator(1, "b", junctions: 2)
  }
  let (extended, extras) = add.assemble(busy, commands)
  assert.eq(busy.lines.first().components.len(), 2)
  assert.eq(extended.lines.first().components.len(), 4)
  assert.eq(extended.lines.first().components.last().junctions, 2)
  assert.eq(extras, ())
  let expanded = fridge-layout(extended, component-gap: 0.5, line-gap: 1.2)
  assert(expanded.gaps.first() > layout.gaps.first())
  assert(expanded.widths.first().last() >= 1.08)
  assert.eq(expanded.line-gap, 1.2)
  let named = (stages: empty.stages, lines: ((id: "drive", label: "Drive"),))
  let (by-id, _) = add.assemble(named, add.filter("drive", "b", kind: "HPF"))
  assert.eq(by-id.lines.first().components.first().kind, "HPF")
  let padded = fridge-layout(busy, attenuator-padding-x: 0.8, attenuator-padding-y: 0.4)
  assert(padded.widths.first().first() > layout.widths.first().first())
  assert(padded.heights.first().first() > layout.heights.first().first())
  assert.eq(padded.widths.at(1), layout.widths.at(1))
  let overridden = (stages: empty.stages, lines: ((components: (
    (type: "attenuator", stage: "a", db: 10, padding-x: 0.8, padding-y: 0.4),
  ),),))
  let override-layout = fridge-layout(overridden)
  assert.eq(override-layout.widths.first().first(), padded.widths.first().first())
  assert.eq(override-layout.heights.first().first(), padded.heights.first().first())
  fridge(overridden, style: (attenuator-padding-x: 0, attenuator-padding-y: 0))
  fridge(busy)
}
