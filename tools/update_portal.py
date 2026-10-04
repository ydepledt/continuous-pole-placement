"""Preview or update the existing mod page through Factorio's official API.

Credentials come from MOD_EDIT_API_KEY or an explicitly named local file.
Never include credentials in the repository or command-line arguments.
"""
import argparse
import difflib
import json
import os
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from uuid import uuid4


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-url", required=True)
    parser.add_argument("--api-key-file", type=Path)
    parser.add_argument("--apply", action="store_true", help="Submit the previewed change")
    args = parser.parse_args()
    if not args.source_url.startswith("https://github.com/"):
        parser.error("source-url must be an HTTPS GitHub repository URL")

    root = Path(__file__).resolve().parents[1]
    info = json.loads((root / "info.json").read_text(encoding="utf-8"))
    details_url = f"https://mods.factorio.com/api/mods/{info['name']}/full"
    with urlopen(details_url, timeout=30) as response:
        current = json.load(response)
    if current["owner"] != info["author"]:
        raise SystemExit("Portal owner differs from the expected mod author")
    old_description = current.get("description", "").replace("\r\n", "\n").strip()
    new_description = (root / "PORTAL.md").read_text(encoding="utf-8").replace("\r\n", "\n").strip()
    if args.source_url not in new_description:
        raise SystemExit("The requested source URL is missing from PORTAL.md")
    print(f"Mod: {info['name']}")
    print(f"Source URL: {current.get('source_url')} -> {args.source_url}")
    print("\n".join(difflib.unified_diff(
        old_description.splitlines(), new_description.splitlines(),
        fromfile="current portal description", tofile="PORTAL.md", lineterm="",
    )))
    if not args.apply:
        print("Preview only; no portal changes submitted.")
        return

    key = (args.api_key_file.read_text(encoding="utf-8-sig").strip()
           if args.api_key_file else os.environ.get("MOD_EDIT_API_KEY", "").strip())
    if not key:
        raise SystemExit("No API key supplied; portal was not modified")
    boundary = "cpp-" + uuid4().hex
    fields = {"mod": info["name"], "source_url": args.source_url,
              "description": new_description + "\n"}
    payload = "".join(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'
        for name, value in fields.items()
    ) + f"--{boundary}--\r\n"
    request = Request(
        "https://mods.factorio.com/api/v2/mods/edit_details", data=payload.encode("utf-8"),
        headers={"Authorization": "Bearer " + key,
                 "Content-Type": "multipart/form-data; boundary=" + boundary}, method="POST",
    )
    try:
        with urlopen(request, timeout=30) as response:
            result = json.load(response)
    except HTTPError as error:
        raise SystemExit(f"Factorio rejected the update (HTTP {error.code}); check the Edit Mods permission") from None
    if result.get("success") is not True:
        raise SystemExit("Factorio did not confirm the update")
    print("Factorio confirmed the description and source URL update.")


if __name__ == "__main__":
    main()
