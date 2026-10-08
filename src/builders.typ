// These commands collect components before measuring and drawing the fridge.
#let component(kind, wire, stage, ..options) = {
  assert(options.pos() == (), message: "Component options must be named.")
  ((_frigorify: "component", wire: wire, component: (..options.named(), type: kind, stage: stage)),)
}
#let attenuator(wire, stage, ..options) = component("attenuator", wire, stage, ..options)
#let amplifier(wire, stage, ..options) = component("amplifier", wire, stage, ..options)
#let circulator(wire, stage, ..options) = component("circulator", wire, stage, ..options)
#let filter(wire, stage, ..options) = component("filter", wire, stage, ..options)
// The callback receives final geometry and returns ordinary CeTZ elements.
#let overlay(callback) = ((_frigorify: "overlay", callback: callback),)

#let assemble(config, body) = {
  assert(type(body) == array, message: "Fridge body must produce component commands or CeTZ elements.")
  let lines = config.lines
  let extras = ()
  for item in body {
    if type(item) == dictionary and item.at("_frigorify", default: none) == "component" {
      let matches = lines
        .enumerate()
        .filter(pair => {
          let (index, wire) = pair
          if type(item.wire) == int { index + 1 == item.wire } else {
            wire.at("id", default: wire.at("label", default: none)) == item.wire
          }
        })
      assert(matches.len() == 1, message: "Component wire must identify exactly one line: " + repr(item.wire))
      let index = matches.first().first()
      let wire = lines.at(index)
      wire.insert("components", wire.at("components", default: ()) + (item.component,))
      lines.at(index) = wire
    } else { extras.push(item) }
  }
  ((..config, lines: lines), extras)
}
