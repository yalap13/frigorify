#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#let config = (first-stage-side: "left", stages: ((id: "a", label: "A"), (id: "b", label: "B")), lines: (
  (id: "one", components: ((type: "attenuator", stage: "a", db: 10), (type: "attenuator", stage: "a", db: 20))),
  (id: "two", components: ((type: "circulator", stage: "a", junctions: 2),)),
  (id: "three", connect: "component-2-1.port-4-bottom"),
))
#context {
  let left = f.fridge-layout(config)
  let right = f.fridge-layout(config, first-stage-side: "right")
  assert.eq(left.stages.first(), 0)
  assert(left.component-starts.first().first() < 0)
  assert(calc.abs(left.component-starts.first().first() + left.widths.first().sum() + left.component-gap) < 1e-9)
  assert.eq(left.left-extent, -left.component-starts.first().first())
  assert(left.gaps.first() < right.gaps.first())
  assert.eq(right.left-extent, 0)
  let target = f.connection-point(config, left, config.lines.last().connect)
  assert(target.point.first() < 0)
  let empty = f.fridge-layout((first-stage-side: "left", stages: config.stages, lines: ((:),)))
  assert.eq(empty.left-extent, 0)
}
#for settings in ((:), (first-stage-side: "left"), (style: (first-stage-side: "left"))) {
  f.fridge(config, ..settings, {
    cetz.draw.get-ctx(ctx => {
      let (_, edge) = cetz.coordinate.resolve(ctx, "component-1-2.east")
      assert(calc.abs(edge.first()) < 1e-9)
      let (_, start) = cetz.coordinate.resolve(ctx, "wire-1.start")
      let (_, component) = cetz.coordinate.resolve(ctx, "component-1-1.west")
      assert(start.first() < component.first())
      let (_, end) = cetz.coordinate.resolve(ctx, "wire-3.end")
      let (_, port) = cetz.coordinate.resolve(ctx, "component-2-1.port-4-bottom")
      for axis in range(3) { assert(calc.abs(end.at(axis) - port.at(axis)) < 1e-9) }
      ()
    })
  })
}
