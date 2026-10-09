# Frigorify documentation

[reference.typ](reference.typ) is the complete reference entrypoint. It includes
[guide.typ](guide.typ), covering configuration, JSON and block examples, anchors,
routing, terminations, style inheritance, first-stage placement, and layout fields.
It then generates function and parameter documentation from all six source modules
using Tidy 0.4.3. CeTZ 0.5.2 is required by the library itself.

Compile from the repository root:

```sh
typst compile --root . docs/reference.typ /tmp/frigorify-reference.pdf
```

The guide is intended to be included by `reference.typ`. Import the library from
`src/frigorify.typ`; use `f.add` for drawing-block builders. Standalone renderers
return CeTZ element arrays, whereas `f.fridge` returns document content.

When changing the API, update its source doc comments and the relevant guide
section together. Run `python3 tests/check.py` and compile the reference to check
code examples, source parsing, and the final document.
