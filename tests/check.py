"""Run layout assertions, render examples, and check configuration failures."""
from pathlib import Path
import json
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def compile_typst(source, output):
    return subprocess.run(
        ["typst", "compile", "--root", str(ROOT), str(source), str(output)],
        capture_output=True, text=True,
    )


with tempfile.TemporaryDirectory(dir=ROOT / "tests") as directory:
    work = Path(directory)
    for source in (*sorted(str(path.relative_to(ROOT)) for path in (ROOT / "tests").glob("*.typ") if path.name != "stroke.typ"),
                   "examples/basic.typ", "examples/block.typ"):
        result = compile_typst(ROOT / source, work / (Path(source).stem + ".pdf"))
        assert result.returncode == 0, result.stderr
        print(f"PASS {source}")

    # Verify actual rendered widths for all three line APIs and overlay callbacks.
    svg = work / "stroke.svg"
    result = compile_typst(ROOT / "tests/stroke.typ", svg)
    assert result.returncode == 0, result.stderr
    widths = [float(node.attrib["stroke-width"]) for node in ET.parse(svg).iter()
              if node.tag.endswith("}path") and "stroke-width" in node.attrib]
    assert sum(abs(width - 2.3) < 1e-6 for width in widths) == 10, widths
    assert sum(abs(width - 0.4) < 1e-6 for width in widths) == 6, widths
    print("PASS line stroke inheritance and explicit overrides")

    cases = [
        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"components": [{"type": "not-connected", "stage": "a"}, {"type": "filter", "stage": "a"}]}]}, "Termination must be the final"),

        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"id": "a"}, {"id": "b"}, {"id": "c"}], "couplers": [{"through": "a", "coupled": "c", "stage": "a"}]}, "Coupler lines must be adjacent"),

        ({"first-stage-side": "above", "stages": [{"id": "a", "label": "A"}], "lines": [{}]}, "first-stage-side must be left or right"),

        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"components": [{"type": "load", "stage": "a", "scale": 0}]}]}, "Termination scale must be a positive"),
        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"termination": {"type": "load", "show-label": "no"}}]}, "Termination show-label must be boolean"),

        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"components": [{"type": "short", "stage": "a"}, {"type": "attenuator", "stage": "a"}]}]}, "Termination must be the final"),
        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"termination": "short", "components": [{"type": "load", "stage": "a"}]}]}, "A termination component cannot share"),

        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"termination": "bad"}]}, "Termination type must be short or load"),
        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"termination": {"type": "load", "direction": "bad"}}]}, "Termination direction"),
        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"termination": "short", "connect": "component-2-1.port-3"}, {"components": [{"type": "circulator", "stage": "a"}]}]}, "A terminated line cannot"),

        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"connect": "component-2-1.port-4-top"}, {"components": [
            {"type": "circulator", "stage": "a"}]}]}, "Unknown circulator connection port"),

        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"components": [
            {"type": "rf-switch", "stage": "a"}, {"type": "filter", "stage": "a"}]}]}, "RF switch must be the final"),

        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"components": [
            {"type": "circulator", "stage": "a", "junctions": 3}]}]}, "Circulator junctions"),
        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"components": [
            {"type": "filter", "stage": "missing"}]}]}, "Unknown stage"),
        ({"stages": [{"id": "a", "label": "A"}], "lines": [{"components": [
            {"type": "mystery", "stage": "a"}]}]}, "Unknown component type"),
        ({"stages": [{"id": "a", "label": "A"}, {"id": "a", "label": "B"}],
          "lines": [{}]}, "Duplicate stage id"),
    ]
    source = work / "invalid.typ"
    source.write_text('#import "../../src/frigorify.typ": fridge\n#fridge(json("invalid.json"))\n')
    for config, message in cases:
        (work / "invalid.json").write_text(json.dumps(config))
        result = compile_typst(source, work / "invalid.pdf")
        assert result.returncode != 0 and message in result.stderr, result.stderr
        print(f"PASS rejects {message.lower()}")
