#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2": draw
#set page(width: auto, height: auto)
#let config = (stages: ((id: "a", label: "A"),), lines: ((label: "1",),))
#for options in ((stroke: 2.3pt), (stroke: 0.6pt, style: (stroke: 2.3pt))) {
  f.fridge(config, ..options, {
    draw.line((0, -1), (1, -1))
    f.sline((0, -2), (1, -2.4))
    f.zline((0, -3), (1, -3.4))
    f.add.overlay(layout => { draw.line((0, -4), (1, -4)) })
    draw.line((0, -5), (1, -5), stroke: 0.4pt)
    f.sline((0, -6), (1, -6.4), stroke: 0.4pt)
    f.zline((0, -7), (1, -7.4), stroke: 0.4pt)
  })
}
