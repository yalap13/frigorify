#import "../src/frigorify.typ" as f
#import "@preview/cetz:0.5.2": draw

#set page(width: auto, height: auto, margin: 14pt)
#set text(font: "IBM Plex Sans", size: 9pt)

#f.fridge(
  (
    stages: ((id: "room", label: "300 K"), (id: "4k", label: "4 K"), (id: "mix", label: "10 mK")),
    lines: ((id: "drive", label: "Drive"), (id: "output", label: "Output"), (id: "flux", label: "Flux"),
      (id: "main", label: "Main"), (id: "coupled", label: "Coupled"), (id: "unused", label: "Unused")),
  ),
  style: (line-gap: 1, component-gap: 0.1, attenuator-padding-x: 0, attenuator-padding-y: 0),
  {
    import f.add: *

    attenuator("drive", "4k", db: 20)
    rf-switch("drive", "mix")
    sline("component-1-2.port-1", right-end(0.5), axis: "y")
    amplifier("output", "4k", direction: "left")
    circulator("output", "mix", junctions: 2, direction: "right")
    filter("output", "mix", kind: "high-pass")
    circulator("flux", "4k", junctions: 2, direction: "left")
    filter("flux", "mix", kind: "band-pass")

    // Terminate a circulator port and route another one to the diagram edge.
    load("component-2-2.port-3-bottom", scale: 0.5, show-label: false)
    zline("component-2-2.port-4-bottom", right-end(-1.4))

    // The coupled input follows its attenuator even when that call comes later.
    attenuator("main", "mix", db: 3)
    directional-coupler("main", "coupled", "mix", name: "dc")
    filter("main", "mix", kind: "LPF")
    attenuator("coupled", "mix", db: 10)
    not-connected("unused", "4k")

    // Named CeTZ anchors are available after the diagram is drawn.
    overlay(layout => {
      draw.content((layout.end / 2, -6.1), [Block commands + port routing + terminations])
    })
  },
)
