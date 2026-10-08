#import "../src/frigorify.typ": fridge

#set page(width: auto, height: auto, margin: 14pt)
#set text(font: "New Computer Modern 08")

#fridge((
  stages: (
    (id: "room", label: "300 K"),
    (id: "4k", label: "4 K"),
    (id: "mix", label: "10 mK"),
  ),
  lines: (
    (
      label: "Input",
      components: (
        (type: "attenuator", stage: "4k", db: 20),
        (type: "attenuator", stage: "mix", db: 20),
        (type: "filter", stage: "mix", kind: "LPF"),
      ),
    ),
    (
      label: "Output",
      port: none,
      color: "#345c9c",
      components: (
        (type: "amplifier", stage: "4k", direction: "left", gain: "HEMT"),
        (type: "circulator", stage: "mix", direction: "left"),
        (type: "circulator", stage: "mix", direction: "right"),
      ),
    ),
  ),
))
