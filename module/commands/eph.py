#!/usr/bin/env python3
import os
import re
import stat
import sys
from dataclasses import dataclass


@dataclass
class Prune:
    empty: bool


@dataclass
class Items:
    items: list[str]


Result = Prune | Items

maindev = os.stat("/").st_dev
permfail = False


def handleDir(path: str) -> Result:
    global permfail

    prune = True
    items = []

    try:
        with os.scandir(path) as scan:
            for item in scan:
                info = os.stat(item.path)
                mode = info.st_mode

                if info.st_dev != maindev:
                    prune = False

                elif stat.S_ISLNK(mode):
                    link = os.readlink(item.path)
                    if re.match("^(/nix/store|/persist)/", link):
                        prune = False

                elif stat.S_ISDIR(mode):
                    result = handleDir(item.path)
                    match result:
                        case Prune(empty):
                            if not empty:
                                items.append(item.path)

                        case Items(it):
                            prune = False
                            items.extend(it)

                elif stat.S_ISREG(mode):
                    items.append(item.path)

    except PermissionError as e:
        permfail = True
        print(f"[1;31m{e}[m", file=sys.stderr)

    except:
        pass

    if prune:
        return Prune(len(items) == 0)

    return Items(sorted(items))


match handleDir(sys.argv[1] if len(sys.argv) > 1 else "/"):
    case Items(items):
        for item in items:
            print(item)

    case r:
        print(r)

if permfail:
    print("[1;31mOutput might be incomplete, rerun as root![m")
