#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2": draw

#set page(width: auto, height: auto, margin: 14pt)
#set text(font: "IBM Plex Sans", size: 9pt)

#f.fridge(
  json("block.json"),
  style: (line-gap: 1, component-gap: 0.1),
  {
    import f.add: *

    attenuator("drive", "4k", db: 20)
    filter("drive", "mix", kind: "low-pass")
    amplifier("output", "4k", direction: "left")
    circulator("output", "mix", junctions: 2, direction: "right")
    filter("output", "mix", kind: "high-pass")
    circulator("flux", "4k")
    filter("flux", "mix", kind: "band-pass")

    // Named CeTZ anchors are available after the diagram is drawn.
    draw.content("component-2-2.north", [Double junction], anchor: "south", padding: 0.08)
    overlay(layout => {
      draw.content((layout.end / 2, -3.1), [JSON stages + Typst components + CeTZ])
    })
  },
)
