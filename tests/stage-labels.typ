#import "../src/frigorify.typ" as f
#set page(width: auto, height: auto, margin: 10pt)
#let config = (
  stages: ((id: "a", label: "4 K"), (id: "b", label: "10 mK")),
  lines: ((label: "Drive",), (label: "Readout",)),
)
#f.fridge(config)
#pagebreak()
#f.fridge(config, stage-label-position: "bottom")
#pagebreak()
#f.fridge(config + (stage-label-position: "bottom",))
#pagebreak()
#f.fridge(config, stage-label-position: "top", style: (stage-label-position: "bottom",))
#pagebreak()
#f.fridge(config + (stage-label-position: "bottom",), stage-label-position: "top")
#pagebreak()
#f.fridge((stages: config.stages, lines: (config.lines.first(),)), stage-label-position: "bottom")
