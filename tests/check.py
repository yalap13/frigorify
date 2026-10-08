"""Run layout assertions, render examples, and check configuration failures."""
from pathlib import Path
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def compile_typst(source, output):
    return subprocess.run(
        ["typst", "compile", "--root", str(ROOT), str(source), str(output)],
        capture_output=True, text=True,
    )


with tempfile.TemporaryDirectory(dir=ROOT / "tests") as directory:
    work = Path(directory)
    for source in ("tests/layout.typ", "examples/basic.typ", "examples/native.typ", "examples/block.typ"):
        result = compile_typst(ROOT / source, work / (Path(source).stem + ".pdf"))
        assert result.returncode == 0, result.stderr
        print(f"PASS {source}")

    cases = [
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
