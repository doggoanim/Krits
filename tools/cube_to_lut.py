#!/usr/bin/env python3
"""Converts a standard .cube 3D LUT (DaVinci Resolve / Adobe format) into the
256x16-style strip PNG Godot's Environment.adjustment_color_correction expects
for a Texture2D LUT: width = size*size, height = size, laid out as `size`
side-by-side tiles (one per blue level), each tile size x size (red across,
green down).

Usage:
    python3 cube_to_lut.py input.cube output.png

Re-run this any time you get a new .cube grade to try — nothing here is
specific to one particular LUT.
"""

import sys
import numpy as np
from PIL import Image


def parse_cube(path: str) -> np.ndarray:
	"""Returns an (N, N, N, 3) float32 array, indexed [r][g][b] -> RGB in 0..1,
	exactly as read from the file (no domain remapping — see the module doc
	comment's assumption that DOMAIN_MIN/MAX is the default 0..1, true for
	the vast majority of exported grades)."""
	size = None
	values = []
	with open(path, "r") as f:
		for line in f:
			line = line.strip()
			if not line or line.startswith("#"):
				continue
			parts = line.split()
			if parts[0] == "LUT_3D_SIZE":
				size = int(parts[1])
				continue
			if parts[0] in ("TITLE", "DOMAIN_MIN", "DOMAIN_MAX", "LUT_1D_SIZE"):
				continue
			if len(parts) == 3:
				try:
					values.append([float(parts[0]), float(parts[1]), float(parts[2])])
				except ValueError:
					continue   # stray non-numeric line; ignore rather than crash

	if size is None:
		raise ValueError("No LUT_3D_SIZE found — is this a 3D .cube file?")
	expected = size ** 3
	if len(values) != expected:
		raise ValueError(f"Expected {expected} entries for LUT_3D_SIZE {size}, found {len(values)}")

	# .cube data order: red fastest, then green, then blue slowest.
	data = np.array(values, dtype=np.float32).reshape(size, size, size, 3)   # [b][g][r] -> rgb
	return data.transpose(2, 1, 0, 3)   # -> [r][g][b] -> rgb


def build_strip(lut: np.ndarray) -> Image.Image:
	size = lut.shape[0]
	img = np.zeros((size, size * size, 3), dtype=np.uint8)
	for b in range(size):
		tile = np.clip(lut[:, :, b, :], 0.0, 1.0)   # [r][g] -> rgb
		tile = (tile * 255.0 + 0.5).astype(np.uint8)
		# img rows are g (top = g=0), columns within the tile are r.
		img[:, b * size:(b + 1) * size, :] = tile.transpose(1, 0, 2)
	return Image.fromarray(img, mode="RGB")


def main() -> None:
	if len(sys.argv) != 3:
		print(__doc__)
		sys.exit(1)
	lut = parse_cube(sys.argv[1])
	build_strip(lut).save(sys.argv[2])
	print(f"Wrote {sys.argv[2]} ({lut.shape[0]}x{lut.shape[0]} LUT -> "
		  f"{lut.shape[0] * lut.shape[0]}x{lut.shape[0]} strip)")


if __name__ == "__main__":
	main()
