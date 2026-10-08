#import "@preview/cetz:0.5.2": draw

// Configuration is deliberately made of JSON-compatible dictionaries and arrays.
#let component-types = ("attenuator", "circulator", "amplifier", "filter")

#let component-label(component) = {
  if "label" in component { component.label } else if component.type == "attenuator" {
    str(component.at("db", default: 0)) + " dB"
  } else if component.type == "amplifier" { component.at("gain", default: "") } else if component.type == "filter" {
    let kind = component.at("kind", default: "LPF")
    if lower(kind) in ("lpf", "low-pass", "lowpass", "hpf", "high-pass", "highpass", "bpf", "band-pass", "bandpass") {
      ""
    } else { kind }
  } else { "" }
}

// Each function emits CeTZ elements, for use inside a canvas.
// x is the symbol's left edge and y is the wire center.
#let attenuator(component, x: 0, y: 0, width: 1, font-size: 9pt, stroke: 0.7pt) = {
  import draw: content, rect
  let half-height = 0.24
  rect((x, y - half-height), (x + width, y + half-height), fill: white, stroke: stroke)
  content((x + width / 2, y), text(size: font-size, component-label(component)))
}

#let amplifier(component, x: 0, y: 0, width: 1, font-size: 9pt, stroke: 0.7pt) = {
  import draw: content, line
  let label = component-label(component)
  let half-height = 0.24
  let left = component.at("direction", default: "right") == "left"
  let triangle-width = calc.sqrt(3) * half-height
  let a = if left { x + triangle-width } else { x }
  let b = if left { x } else { x + triangle-width }
  line((a, y - half-height), (b, y), (a, y + half-height), close: true, fill: white, stroke: stroke)
  if label != "" { content((x + triangle-width / 2, y + 0.38), text(size: font-size, label)) }
}

#let circulator(component, x: 0, y: 0, width: 1, font-size: 9pt, stroke: 0.7pt) = {
  import draw: arc, circle, content, group, rect-around
  let junctions = component.at("junctions", default: 1)
  assert(junctions in (1, 2), message: "Circulator junctions must be 1 or 2.")
  let label = component-label(component)
  group({
    for index in range(junctions) {
      let mid = x + 0.27 + index * 0.54
      circle((mid, y), radius: 0.27, fill: white, stroke: stroke, name: "junction-" + str(index))
      let reverse = component.at("direction", default: "right") == "left"
      arc(
        (mid, y),
        anchor: "origin",
        start: if reverse { 40deg } else { 140deg },
        delta: if reverse { -250deg } else { 250deg },
        radius: 0.17,
        stroke: stroke,
        mark: (end: "curved-stealth", scale: 0.3),
      )
    }
    if junctions == 2 {
      rect-around("junction-0", "junction-1", padding: 0, stroke: stroke, fill: none)
    }
  })
  if label != "" { content((x + junctions * 0.27, y + 0.4), text(size: font-size, label)) }
}

#let filter(component, x: 0, y: 0, width: 1, font-size: 9pt, stroke: 0.7pt) = {
  import draw: content, line, rect
  let kind = lower(component.at("kind", default: "LPF"))
  let half-height = 0.24
  rect((x, y - half-height), (x + width, y + half-height), fill: white, stroke: stroke)
  let left = x + 0.15 * width
  let right = x + 0.85 * width
  let mid = x + width / 2
  if kind in ("lpf", "low-pass", "lowpass") {
    line((left, y + 0.12), (mid, y + 0.12), (right, y - 0.12), stroke: stroke)
  } else if kind in ("hpf", "high-pass", "highpass") {
    line((left, y - 0.12), (mid, y + 0.12), (right, y + 0.12), stroke: stroke)
  } else if kind in ("bpf", "band-pass", "bandpass") {
    line(
      (left, y - 0.12),
      (x + 0.35 * width, y + 0.12),
      (x + 0.65 * width, y + 0.12),
      (right, y - 0.12),
      stroke: stroke,
    )
  } else {
    // Preserve labels for other existing filter kinds such as RC.
    content((mid, y), text(size: font-size, component.at("label", default: component.at("kind", default: "LPF"))))
  }
  if kind in ("lpf", "low-pass", "lowpass", "hpf", "high-pass", "highpass", "bpf", "band-pass", "bandpass") {
    let label = component-label(component)
    if label != "" { content((mid, y + 0.38), text(size: font-size, label)) }
  }
}

// Keep the configuration-driven entrypoint shared by all component types.
// width reserves horizontal space; triangles and circles have fixed sizes.
#let fridge-component(component, x: 0, y: 0, width: 1, font-size: 9pt, stroke: 0.7pt) = {
  let renderers = (attenuator: attenuator, amplifier: amplifier, circulator: circulator, filter: filter)
  assert(component.type in renderers, message: "Unknown component type: " + repr(component.type))
  let render = renderers.at(component.type)
  render(component, x: x, y: y, width: width, font-size: font-size, stroke: stroke)
}
