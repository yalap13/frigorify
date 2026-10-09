#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2" as cetz
#set page(width: auto, height: auto)
#let config = (stages: ((id: "a", label: "A"), (id: "b", label: "B")), lines: ((id: "one",), (id: "two",)))
#let commands = {
  f.add.short("one", "a")
  f.add.attenuator("two", "a", db: 20)
  f.add.load("two", stage: "b")
}
#let (assembled, extras) = f.add.assemble(config, commands)
#assert.eq(assembled.lines.first().components.first().type, "short")
#assert.eq(assembled.lines.last().components.last().stage, "b")
#assert.eq(extras, ())
#f.fridge(config, line-gap: 1.4, {
  commands
  cetz.draw.get-ctx(ctx => {
    for (line, component) in (("wire-1", "component-1-1"), ("wire-2", "component-2-2")) {
      let (_, end) = cetz.coordinate.resolve(ctx, line + ".end")
      let (_, input) = cetz.coordinate.resolve(ctx, component + ".in")
      for axis in range(3) { assert(calc.abs(end.at(axis) - input.at(axis)) < 1e-9) }
    }
    ()
  })
})
