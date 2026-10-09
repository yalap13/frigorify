#import "@preview/tidy:0.4.3"

#set page(margin: 2cm)
#set text(size: 10pt)
#show heading.where(level: 1): set heading(numbering: none)

= Frigorify API reference

Numeric geometry uses canvas units (`unit`, default 1 cm). Import the main
module with `#import "src/frigorify.typ" as f`. The builder namespace is `f.add`.

#include "guide.typ"

#pagebreak()
== Diagram and layout
#tidy.show-module(tidy.parse-module(read("../src/frigorify.typ"), name: "frigorify"))

#pagebreak()
== Standalone CeTZ symbols

The following functions are re-exported by the main module. Use them inside a
CeTZ canvas; they return drawing elements rather than standalone document content.
#tidy.show-module(tidy.parse-module(read("../src/components.typ"), name: "components"))

#pagebreak()
== Drawing-block commands: add

Use these functions through `f.add` in the optional drawing block of `f.fridge`.
#tidy.show-module(tidy.parse-module(read("../src/builders.typ"), name: "add"))

#pagebreak()
== Routed lines

#tidy.show-module(tidy.parse-module(read("../src/lines.typ"), name: "lines"))

#pagebreak()
== Ground terminations
#tidy.show-module(tidy.parse-module(read("../src/terminations.typ"), name: "terminations"))

#pagebreak()
== Directional couplers
#tidy.show-module(tidy.parse-module(read("../src/couplers.typ"), name: "couplers"))
