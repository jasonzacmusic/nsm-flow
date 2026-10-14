#!/usr/bin/env python3
"""Repair rpm 0.16's partial-write digest bug in unsigned gzip RPMs only.

Sha256Writer hashes the entire input buffer before the compressor reports how
many bytes it consumed. Large files can therefore get a wrong PAYLOADDIGESTALT.
Retain the exact payload and every field except that digest and HEADER SHA256.
Never rewrite a signed package, a corrupt header, or a corrupt compressed payload.
The result must still pass the system RPM digest and extraction checks.
"""
import gzip
import hashlib
import json
from pathlib import Path
import struct
import sys


def header(data, offset):
    if data[offset:offset + 4] != b"\x8e\xad\xe8\x01":
        raise ValueError("Unsupported RPM header")
    count, size = struct.unpack_from(">II", data, offset + 8)
    start = offset + 16 + count * 16
    end = start + size
    if end > len(data):
        raise ValueError("Truncated RPM header")
    tags = {}
    for index in range(count):
        tag, kind, position, length = struct.unpack_from(">IIII", data, offset + 16 + index * 16)
        if tag in tags or position >= size:
            raise ValueError("Duplicate or invalid RPM tag")
        tags[tag] = (kind, start + position, length)
    return end, tags


def string(data, tags, tag):
    kind, position, count = tags[tag]
    if kind not in (6, 8) or count != 1:
        raise ValueError("Unsupported RPM string tag")
    return bytes(data[position:data.index(0, position)]).decode("ascii")


def replace_digest(data, tags, tag, digest):
    old = string(data, tags, tag)
    if len(old) != 64 or any(c not in "0123456789abcdef" for c in old):
        raise ValueError("Invalid SHA256 digest field")
    position = tags[tag][1]
    data[position:position + 64] = digest.encode("ascii")


def repair(raw):
    data = bytearray(raw)
    if data[:4] != b"\xed\xab\xee\xdb":
        raise ValueError("Not an RPM")
    signature_end, signature = header(data, 96)
    # Only the immutable-region marker and unsigned SHA256 digest are accepted.
    if set(signature) != {62, 273}:
        raise ValueError("Refusing signed or unrecognized RPM signature header")
    main = (signature_end + 7) // 8 * 8
    payload_start, tags = header(data, main)
    if string(data, signature, 273) != hashlib.sha256(data[main:payload_start]).hexdigest():
        raise ValueError("Original RPM header digest mismatch")
    if string(data, tags, 1124) != "cpio" or string(data, tags, 1125) != "gzip":
        raise ValueError("Only gzip/cpio RPMs are supported")
    kind, position, count = tags[5093]
    if (kind, count) != (4, 1) or struct.unpack_from(">I", data, position)[0] != 8:
        raise ValueError("Only SHA256 payload digests are supported")
    compressed = data[payload_start:]
    if string(data, tags, 5092) != hashlib.sha256(compressed).hexdigest():
        raise ValueError("Original compressed RPM payload digest mismatch")
    actual = hashlib.sha256(gzip.decompress(compressed)).hexdigest()
    if string(data, tags, 5097) == actual:
        return bytes(data)
    replace_digest(data, tags, 5097, actual)
    replace_digest(data, signature, 273, hashlib.sha256(data[main:payload_start]).hexdigest())
    assert data[payload_start:] == compressed
    return bytes(data)


if __name__ == "__main__":
    records = []
    for argument in sys.argv[1:]:
        path = Path(argument)
        original = path.read_bytes()
        fixed = repair(original)
        if fixed != original:
            path.write_bytes(fixed)
        records.append({"file": path.name, "originalSHA256": hashlib.sha256(original).hexdigest(),
                        "sha256": hashlib.sha256(fixed).hexdigest(), "changed": fixed != original})
    if not records:
        raise SystemExit("Pass at least one unsigned RPM")
    print(json.dumps(records, indent=2))
