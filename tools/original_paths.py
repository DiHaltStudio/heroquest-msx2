"""Locations of user-supplied original game data (never distributed)."""
import os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_DIR = Path(os.environ.get("ORIGINAL_DIR", str(ROOT.parent / "originals"))).expanduser().resolve()
ZX_ORIG = Path(os.environ.get("HEROQUEST_ZX_ORIG", str(ORIGINAL_DIR / "ZX" / "orig"))).expanduser().resolve()
