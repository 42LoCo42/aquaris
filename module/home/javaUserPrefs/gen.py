#!/usr/bin/env python3
import base64
import json
import os
import pathlib
import sys
from io import StringIO

from yq import yq

# https://hg.openjdk.org/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/prefs/Base64.java#l100
# https://hg.openjdk.org/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/prefs/Base64.java#l115
table = str.maketrans(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ/",
    "!\"#$%&'(),-.:;<>@[]^`_{|}~?",
)


# https://hg.openjdk.org/jdk8/jdk8/jdk/file/687fd7c7986d/src/solaris/classes/java/util/prefs/FileSystemPreferences.java#l837
def isDirChar(c) -> bool:
    return c > chr(0x1F) and c < chr(0x7F) and c not in "/._"


# https://hg.openjdk.org/jdk8/jdk8/jdk/file/687fd7c7986d/src/solaris/classes/java/util/prefs/FileSystemPreferences.java#l847
def dirName(name: str) -> str:
    if all(isDirChar(c) for c in name):
        return name
    return "_" + base64.b64encode(byteArray(name)).decode().translate(table)


# https://hg.openjdk.org/jdk8/jdk8/jdk/file/687fd7c7986d/src/solaris/classes/java/util/prefs/FileSystemPreferences.java#l858
def byteArray(s: str) -> bytes:
    result = bytearray()
    for c in s:
        o = ord(c)
        result.append((o >> (8 * 1) & 0xFF))
        result.append((o >> (8 * 0) & 0xFF))
    return bytes(result)


# escape special chars for tmpfiles.d(5) config entries
def escape(s: str) -> str:
    return "".join(
        [c if c == "/" or c.isalnum() else "\\" + hex(ord(c))[1:] for c in s]
    )


out = str(os.getenv("out"))
with open("conf", "w") as conf:
    files = json.load(sys.stdin)
    for rawPath, entry in files.items():
        oldPath = pathlib.Path(rawPath)
        newPath = pathlib.Path()

        for part in oldPath.parts:
            newPath /= dirName(part)

        outPath = pathlib.Path(out) / "files" / newPath
        outPath.mkdir(parents=True, exist_ok=True)

        with open(outPath / "prefs.xml", "w") as f:
            if entry["raw"]:
                f.write(entry["val"])
            else:
                yq(
                    input_streams=[StringIO(entry["val"])],
                    input_format="yaml",
                    output_stream=f,
                    output_format="xml",
                    xml_dtd=True,
                    exit_func=lambda _: None,
                )

        print(
            "L+ %h/.java/.userPrefs/",
            escape(str(newPath)),
            " - - - - ",
            escape(str(outPath)),
            sep="",
            file=conf,
        )
