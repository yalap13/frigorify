// These commands collect components before measuring and drawing the fridge.
#let component(kind, wire, stage, ..options) = {
  assert(options.pos() == (), message: "Component options must be named.")
  ((_frigorify: "component", wire: wire, component: (..options.named(), type: kind, stage: stage)),)
}
/// Add an attenuator to a wire and stage from the optional `fridge` drawing block. Use as `add.attenuator`; commands are collected before layout and appended in call order.
/// -> array
#let attenuator(
  /// One-based wire number, or string matching a wire `id` (falling back to `label` when no ID exists). Must identify exactly one line.
  /// -> int | str
  wire,
  /// ID of the stage where the component is mounted.
  /// -> str
  stage,
  /// Named component fields: `db` (default 0), `label`, `width`, `padding-x`, and `padding-y`. Padding values are nonnegative canvas units per side. Positional options are rejected.
  /// -> arguments
  ..options,
) = component("attenuator", wire, stage, ..options)
/// Add an amplifier to a wire and stage from the optional `fridge` drawing block. Use as `add.amplifier`; commands are collected before layout and appended in call order.
/// -> array
#let amplifier(
  /// One-based wire number, or string matching a wire `id` (falling back to `label` when no ID exists). Must identify exactly one line.
  /// -> int | str
  wire,
  /// ID of the stage where the component is mounted.
  /// -> str
  stage,
  /// Named component fields: `gain` (string), `label`, `width`, and `direction` (`right` or `left`). Positional options are rejected.
  /// -> arguments
  ..options,
) = component("amplifier", wire, stage, ..options)
/// Add an circulator to a wire and stage from the optional `fridge` drawing block. Use as `add.circulator`; commands are collected before layout and appended in call order.
/// -> array
#let circulator(
  /// One-based wire number, or string matching a wire `id` (falling back to `label` when no ID exists). Must identify exactly one line.
  /// -> int | str
  wire,
  /// ID of the stage where the component is mounted.
  /// -> str
  stage,
  /// Named component fields: `junctions` (1 or 2), `label`, `width`, and `direction` (`right` or `left`). Positional options are rejected.
  /// -> arguments
  ..options,
) = component("circulator", wire, stage, ..options)
/// Add an filter to a wire and stage from the optional `fridge` drawing block. Use as `add.filter`; commands are collected before layout and appended in call order.
/// -> array
#let filter(
  /// One-based wire number, or string matching a wire `id` (falling back to `label` when no ID exists). Must identify exactly one line.
  /// -> int | str
  wire,
  /// ID of the stage where the component is mounted.
  /// -> str
  stage,
  /// Named component fields: `kind` (default `LPF`), `label`, and `width`. LPF, HPF, and BPF support spelled-out names. Positional options are rejected.
  /// -> arguments
  ..options,
) = component("filter", wire, stage, ..options)
// The callback receives final geometry and returns ordinary CeTZ elements.
/// Schedule a CeTZ overlay that uses final measured geometry. Use in the optional `fridge` drawing block as `add.overlay(callback)`.
/// -> array
#let overlay(
  /// Function receiving the final layout dictionary and returning an array of CeTZ drawing elements.
  /// -> function
  callback,
) = ((_frigorify: "overlay", callback: callback),)

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
