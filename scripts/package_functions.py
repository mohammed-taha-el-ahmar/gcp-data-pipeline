from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FUNCTIONS_DIR = ROOT / "functions"
SHARED_DIR = ROOT / "shared"
BUILD_DIR = ROOT / "build"

FUNCTION_NAMES = ["ingest", "transform", "latest"]


def package_function(name: str) -> Path:
    source_dir = FUNCTIONS_DIR / name
    staging_dir = BUILD_DIR / name
    archive_path = BUILD_DIR / name

    if not source_dir.exists():
        raise FileNotFoundError(f"Function source not found: {source_dir}")

    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir(parents=True, exist_ok=True)

    shutil.copy(source_dir / "main.py", staging_dir / "main.py")
    shutil.copy(source_dir / "requirements.txt", staging_dir / "requirements.txt")
    shutil.copytree(SHARED_DIR, staging_dir / "shared", dirs_exist_ok=True)

    zip_file = shutil.make_archive(str(archive_path), "zip", root_dir=staging_dir)
    return Path(zip_file)


def main() -> None:
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    created = [package_function(name) for name in FUNCTION_NAMES]
    print("Created deployment archives:")
    for archive in created:
        print(f"- {archive.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
