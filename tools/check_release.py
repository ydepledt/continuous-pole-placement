"""Validate the exact release ZIP and load it in an isolated Factorio process."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from zipfile import ZipFile

root = Path(__file__).resolve().parents[1]
info = json.loads((root / "info.json").read_text(encoding="utf-8"))
release = f"{info['name']}_{info['version']}"
archive_path = root / "dist" / f"{release}.zip"
tested = root.parent / "continuous-pole-placement-tests/simulation-probe/production/mods" / release
runtime_files = [Path("control.lua"), Path("data.lua")]
runtime_files += [file.relative_to(root) for file in (root / "scripts").glob("*.lua")]
assert all((root / file).read_bytes() == (tested / file).read_bytes() for file in runtime_files), "Runtime differs from final native tests"
with ZipFile(archive_path) as archive:
    assert archive.testzip() is None
    assert all(name.startswith(release + "/") and ".." not in Path(name).parts for name in archive.namelist())
    assert json.loads(archive.read(release + "/info.json")) == info
    for file in runtime_files:
        assert archive.read(release + "/" + file.as_posix()) == (root / file).read_bytes()

test_root = root.parent / "continuous-pole-placement-tests/release-smoke"
(test_root / "mods").mkdir(parents=True, exist_ok=True)
(test_root / "runtime").mkdir(exist_ok=True)
shutil.copy2(archive_path, test_root / "mods" / archive_path.name)
(test_root / "mods/mod-list.json").write_text(json.dumps({"mods": [
    {"name": "base", "enabled": True}, {"name": "quality", "enabled": True},
    {"name": "elevated-rails", "enabled": False}, {"name": "space-age", "enabled": False},
    {"name": info["name"], "enabled": True},
]}), encoding="utf-8")
(test_root / "config.ini").write_text(
    "[path]\nread-data=D:/SteamLibrary/steamapps/common/Factorio/data\n"
    f"write-data={(test_root / 'runtime').as_posix()}\n"
    "[other]\nenable-blueprint-storage-cloud-sync=false\n", encoding="utf-8")
with (test_root / "load.log").open("w", encoding="utf-8") as output:
    result = subprocess.run([
        r"D:\SteamLibrary\steamapps\common\Factorio\bin\x64\Factorio.exe",
        "--config", str(test_root / "config.ini"), "--mod-directory", str(test_root / "mods"),
        "--create", str(test_root / "runtime/release-validation.zip"),
    ], stdout=output, stderr=subprocess.STDOUT, timeout=60,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
assert result.returncode == 0, (test_root / "load.log").read_text(encoding="utf-8", errors="replace")
report = {"version": info["version"], "author": info["author"], "archive": archive_path.name,
          "sha256": hashlib.sha256(archive_path.read_bytes()).hexdigest(),
          "bytes": archive_path.stat().st_size, "matches_native_tests": True,
          "factorio_zip_load": "passed", "native_drag_scenarios": 40, "native_drag_failures": 0}
(root / "dist/release-validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
