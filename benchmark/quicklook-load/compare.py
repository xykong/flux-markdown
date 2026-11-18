"""Compare built FluxMarkdown renderers, serially, in fresh windowless native WebKit processes."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SIZE = 2 * 1024 * 1024
CASES = ("dense", "prose", "refs", "html", "emoji", "chinese", "single")


def fixture(case):
    start = "# Session\n\n"
    end = "\n\nLAST-MARKER\n"
    if case == "refs":
        start += "[guide topic]\n\n"
        end = "\n\n[guide\ntopic]: https://example.com/guide" + end
    elif case == "html":
        end = "\n\n<details>\n\nContents\n\n</details>" + end
    parts = [start]
    used = len((start + end).encode())
    i = 0
    while case != "single":
        if case == "prose":
            block = f"Paragraph {i}. " + "A reader opens a Markdown document. " * 15 + "\n\n"
        elif case == "chinese":
            block = f"## 第 {i} 页\n\n" + "阅读中文文档时可以从标题导航到这一段。" * 30 + "\n\n"
        else:
            reply = "Reply :smile: " if case == "emoji" else "Reply "
            block = (f"## Turn {i}\n\n> prompt {i}\n\n" + reply + "words " * 80 + "\n\n```text\n"
                     + f"log line {i}\n" * 12 + f"```\n\n| a | b |\n|---|---|\n| {i} | x |\n\n")
        n = len(block.encode())
        if used + n > SIZE:
            break
        parts.append(block)
        used += n
        i += 1
    return "".join(parts) + "P" * (SIZE - used) + end


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--renderer", nargs=2, metavar=("LABEL", "DIST"), action="append", required=True)
    cli.add_argument("--case", choices=CASES, default="dense")
    cli.add_argument("--mode", choices=("head", "follow", "lines"), default="head")
    cli.add_argument("--runs", type=int, default=5)
    args = cli.parse_args()
    if args.runs < 1:
        cli.error("runs must be positive")
    if len({label for label, _ in args.renderer}) != len(args.renderer):
        cli.error("renderer labels must be unique")
    for _, directory in args.renderer:
        if not (Path(directory) / "index.html").is_file():
            cli.error(f"no built index.html in {directory}")
    with tempfile.TemporaryDirectory(prefix="flux-quicklook-load-") as folder:
        directory = Path(folder)
        executable = directory / "probe"
        subprocess.run(["swiftc", ROOT / "Tests/Support/TestWindowPolicy.swift",
                        ROOT / "Sources/Shared/RendererBundleSchemeHandler.swift",
                        ROOT / "scripts/research/issue64-math/main.swift", "-o", executable], check=True)
        script = directory / "measure.js"
        script.write_text(f"const mode = {json.dumps(args.mode)};\n" +
                          Path(__file__).with_name("measure.js").read_text())
        source = directory / "fixture.md"
        source.write_text(fixture(args.case))
        assert source.stat().st_size == SIZE
        # Only the measurement width is controlled. Prevent inherited probe flags
        # from opening a UI, changing zoom, or interrupting the cold-start sample.
        env = {k: v for k, v in os.environ.items() if not k.startswith("FLUX_MATH_PROBE_")}
        rows = []
        for run in range(args.runs):
            offset = run % len(args.renderer)
            for label, dist in args.renderer[offset:] + args.renderer[:offset]:
                completed = subprocess.run([executable, "flux-renderer://bundle/index.html",
                                            Path(dist).resolve(), script, source, "50"],
                                           capture_output=True, text=True, env=env)
                if completed.returncode:
                    raise RuntimeError(f"{label}, repetition {run + 1}: {completed.stderr.strip()}")
                row = json.loads(completed.stdout)
                rows.append(dict(label=label, run=run + 1, **row))
        print(json.dumps(dict(fixture=args.case, mode=args.mode, samples=rows), indent=2))


if __name__ == "__main__":
    main()
