#!/usr/bin/env python3
"""Normalize an I3S Scene Layer Package (.slpk) for spec-compliant serving.

loaders.gl's tile-converter writes the package's `.gz` resources *uncompressed*
(plain JSON / binary content under a `.gz` name). The I3S spec requires those
resources to be real gzip streams (they are served with `Content-Encoding: gzip`),
so ArcGIS clients and strict SLPK readers reject the raw output.

This rewrites the package as a STORED zip where every `.gz` entry that isn't already
a gzip stream is gzip-compressed. Other entries are copied verbatim.

Usage: normalize_slpk.py <input.slpk> <output.slpk>
"""
import sys
import io
import gzip
import zipfile


def normalize(src: str, dst: str) -> None:
    with zipfile.ZipFile(src) as zin, \
         zipfile.ZipFile(dst, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as zout:
        fixed = 0
        for info in zin.infolist():
            data = zin.read(info.filename)
            if info.filename.endswith(".gz") and data[:2] != b"\x1f\x8b":
                buf = io.BytesIO()
                with gzip.GzipFile(fileobj=buf, mode="wb", mtime=0) as g:
                    g.write(data)
                data = buf.getvalue()
                fixed += 1
            # I3S resources must be STORED (random-access) — never deflate inside the zip.
            zout.writestr(info.filename, data, compress_type=zipfile.ZIP_STORED)
        print(f"    normalized: re-gzipped {fixed} entr{'y' if fixed == 1 else 'ies'}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: normalize_slpk.py <input.slpk> <output.slpk>")
    normalize(sys.argv[1], sys.argv[2])
