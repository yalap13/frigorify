#import "@preview/cetz:0.5.2" as cetz
#import "../src/frigorify.typ": circulator, sline, zline
#set page(width: auto, height: auto)
#cetz.canvas({
  for (name, junctions, direction, y) in (("single", 1, "right", 0), ("double", 2, "left", -2)) {
    cetz.draw.group(name: name, {
      circulator((type: "circulator", junctions: junctions, direction: direction, label: "Long label"), x: 1, y: y, width: 4)
    })
    cetz.draw.get-ctx(ctx => {
      let expected = (
        ("in", (1, y)), ("out", (1 + junctions * 0.54, y)),
        ("port-1", (1, y)), ("port-2", (1 + junctions * 0.54, y)),
        ("port-3", (1.27, y - 0.27)),
      )
      if junctions == 2 { expected.push(("port-4", (1.81, y - 0.27))) }
      for index in range(junctions) {
        let mid = 1.27 + index * 0.54
        expected += (("port-" + str(index + 3) + "-top", (mid, y + 0.27)),
          ("port-" + str(index + 3) + "-bottom", (mid, y - 0.27)))
        let prefix = "junction-" + str(index + 1) + "-port-"
        expected += ((prefix + "1", (mid - 0.27, y)), (prefix + "2", (mid + 0.27, y)), (prefix + "3", (mid, y - 0.27)))
        expected += ((prefix + "3-top", (mid, y + 0.27)), (prefix + "3-bottom", (mid, y - 0.27)))
      }
      for (port, point) in expected {
        let (_, actual) = cetz.coordinate.resolve(ctx, name + "." + port)
        for axis in range(2) { assert(calc.abs(actual.at(axis) - point.at(axis)) < 1e-9) }
      }
      ()
    })
    zline(name + ".port-3", (3, y - 0.8), axis: "y")
  }
  sline("double.port-4", (3, -3.2), axis: "y")
})
