#import "@preview/tidy:0.4.3"

#set page(margin: 2cm)
#set text(size: 10pt)
#set heading(numbering: "I.A.i.a")
#show heading.where(level: 1): it => block(smallcaps(it), below: 1em)
#show heading.where(level: 5): set heading(numbering: none)
#show heading.where(level: 6): set heading(numbering: none)

#align(center, text(size: 14pt)[
  *`frigorify` Manual*\
  v0.1.0
])

#outline(depth: 4)

#include "guide.typ"

#pagebreak()
= API Reference

== Diagram and layout
#tidy.show-module(tidy.parse-module(read("../src/frigorify.typ"), name: "frigorify"), first-heading-level: 3)

#pagebreak()
== Standalone CeTZ symbols

The following functions are re-exported by the main module. Use them inside a
CeTZ canvas; they return drawing elements rather than standalone document content.
#tidy.show-module(tidy.parse-module(read("../src/components.typ"), name: "components"), first-heading-level: 3)

#pagebreak()
== Drawing-block commands: add

Use these functions through `f.add` in the optional drawing block of `f.fridge`.
#tidy.show-module(tidy.parse-module(read("../src/builders.typ"), name: "add"), first-heading-level: 3)

#pagebreak()
== Routed lines

#tidy.show-module(tidy.parse-module(read("../src/lines.typ"), name: "lines"), first-heading-level: 3)

#pagebreak()
== Ground terminations
#tidy.show-module(tidy.parse-module(read("../src/terminations.typ"), name: "terminations"), first-heading-level: 3)

#pagebreak()
== Directional couplers
#tidy.show-module(tidy.parse-module(read("../src/couplers.typ"), name: "couplers"), first-heading-level: 3)
