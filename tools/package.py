"""Create the installable ZIP without bundling test runtimes or local state."""
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
info = json.loads((root / "info.json").read_text(encoding="utf-8"))
prefix = f"{info['name']}_{info['version']}"
destination = root / "dist" / f"{prefix}.zip"
destination.parent.mkdir(exist_ok=True)
files = [root / name for name in (
    "info.json", "data.lua", "control.lua", "README.md", "TESTING.md",
    "LICENSE", "changelog.txt", "thumbnail.png",
)]
for folder in ("scripts", "locale", "graphics", "tests"):
    files.extend(path for path in (root / folder).rglob("*") if path.is_file())
with ZipFile(destination, "w", compression=ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, f"{prefix}/{path.relative_to(root).as_posix()}")
with ZipFile(destination) as archive:
    assert archive.testzip() is None
print(destination)
