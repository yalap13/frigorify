#import "@preview/cetz:0.5.2": canvas, draw
#import "../src/lines.typ": route-points
#import "../src/frigorify.typ": sline, zline
#set page(width: auto, height: auto)
#canvas({
  draw.anchor("start", (0, 0))
  draw.get-ctx(ctx => {
    assert.eq(route-points(ctx, ("start", (4, 2)), "x", 50%), ((0, 0), (2, 0), (2, 2), (4, 2)))
    assert.eq(route-points(ctx, ((0, 0), (4, 2)), "y", 25%), ((0, 0), (0, 0.5), (4, 0.5), (4, 2)))
    assert.eq(route-points(ctx, ((0, 0), (4, 2)), "x", 100%), ((0, 0), (4, 0), (4, 2)))
    assert.eq(route-points(ctx, ((0, 0), (4, 2)), "y", 100%), ((0, 0), (0, 2), (4, 2)))
    assert.eq(route-points(ctx, ((4, 2), (0, 0)), "x", 50%), ((4, 2), (2, 2), (2, 0), (0, 0)))
    assert.eq(route-points(ctx, ((0, 0), (0, 0)), "x", 50%), ((0, 0), (0, 0)))
    assert.eq(route-points(ctx, ((0, 0), (2, 0), (2, 2)), "x", 50%), ((0, 0), (1, 0), (2, 0), (2, 2)))
    ()
  })
  zline("start", (4, 2), name: "route", stroke: blue)
  sline((0, -1), (4, -3), axis: "y", stroke: red)
  draw.content("route.50%", [Route])
})
