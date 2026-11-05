#!/usr/bin/env python
"""Yangi versiyani GitHub Releases'ga chiqarish (to'liq APK + kichik patchlar).

Ilova avto-yangilanishda avval kichik patchni (odatda bir necha MB) yuklab,
o'rnatilgan APK'ga qo'llaydi; patch mos kelmasa to'liq APK yuklanadi.

Tartib:
  1. app/pubspec.yaml'da version'ni oshiring, `flutter build apk --release`,
     app-release.apk'ni loyiha ildizidagi ustun-dokon.apk'ga ko'chiring.
  2. Kodni commit + push qiling.
  3. python tools/release.py --notes "Nima o'zgardi"

Bu skript: oldingi relizlarning APK'sini yuklaydi, har biri uchun patch yaratadi,
patchni Dart kodi (telefondagi bilan bir xil) bilan tekshiradi, update.json
yozadi va hammasini reliz sifatida yuklaydi (--dry-run: yuklamaydi).
"""
import argparse
import bz2
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

REPO = "abdurakmgofurov-Pro/Ustun-Dokon"
ROOT = Path(__file__).resolve().parent.parent
APK_NAME = "ustun-dokon.apk"
CHUNK = 1 << 20


def sh(*cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, capture_output=True, **kw).stdout


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1 << 20):
            h.update(chunk)
    return h.hexdigest()


def offtin(b: bytes) -> int:
    mag = int.from_bytes(b, "little") & ((1 << 63) - 1)
    return -mag if b[7] & 0x80 else mag


def make_patch(old: bytes, new: bytes) -> bytes:
    """bsdiff farqini hisoblab, uni telefon o'qiydigan UDP2 formatiga o'giradi."""
    import bsdiff4

    bs = bsdiff4.diff(old, new)
    assert bs[:8] == b"BSDIFF40", "kutilmagan bsdiff formati"
    clen, dlen, newsize = offtin(bs[8:16]), offtin(bs[16:24]), offtin(bs[24:32])
    ctrl_raw = bz2.decompress(bs[32 : 32 + clen])
    diff = bz2.decompress(bs[32 + clen : 32 + clen + dlen])
    extra = bz2.decompress(bs[32 + clen + dlen :])
    assert newsize == len(new)

    triples = [
        tuple(offtin(ctrl_raw[i + k : i + k + 8]) for k in (0, 8, 16))
        for i in range(0, len(ctrl_raw), 24)
    ]
    ctrl = b"".join(struct.pack("<qqq", *t) for t in triples)

    ctrl_z = zlib.compress(ctrl, 9)
    extra_z = zlib.compress(extra, 9)
    chunks = [
        zlib.compress(diff[i : i + CHUNK], 9) for i in range(0, len(diff), CHUNK)
    ]
    header = (
        b"UDP2"
        + struct.pack("<QQQQQ", newsize, len(triples), len(ctrl_z), len(extra_z), len(extra))
        + struct.pack("<II", CHUNK, len(chunks))
        + b"".join(struct.pack("<I", len(c)) for c in chunks)
    )
    return header + ctrl_z + extra_z + b"".join(chunks)


def pubspec_version() -> str:
    text = (ROOT / "app" / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)", text, re.M)
    if not m:
        sys.exit("pubspec.yaml'da version topilmadi")
    return m.group(1)


def vtuple(v: str):
    return tuple(int(p) for p in v.split("."))


def find_dart() -> str:
    for cand in (shutil.which("dart"), "C:/flutter/bin/dart.bat", "C:/flutter/bin/dart"):
        if cand and Path(cand).exists():
            return cand
    sys.exit("dart topilmadi (Flutter SDK PATH'da bo'lishi kerak)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--notes", required=True, help="Reliz izohi")
    ap.add_argument("--from", dest="froms", nargs="*", help="Qaysi versiyalardan patch (standart: oxirgi reliz)")
    ap.add_argument("--keep", type=int, default=1, help="Nechta oldingi reliz uchun patch (standart 1)")
    ap.add_argument("--dry-run", action="store_true", help="Yuklamasdan faqat tayyorlash")
    args = ap.parse_args()

    version = pubspec_version()
    tag = f"v{version}"
    apk = ROOT / APK_NAME
    if not apk.exists():
        sys.exit(f"{APK_NAME} topilmadi (avval APK yig'ib, loyiha ildiziga ko'chiring)")

    releases = json.loads(
        sh("gh", "release", "list", "--repo", REPO, "--limit", "30", "--json", "tagName")
    )
    existing = [r["tagName"] for r in releases]
    if tag in existing:
        sys.exit(f"{tag} allaqachon chiqarilgan. pubspec.yaml'da versiyani oshiring.")
    older = sorted(
        {t[1:] for t in existing if re.fullmatch(r"v\d+\.\d+\.\d+", t) and vtuple(t[1:]) < vtuple(version)},
        key=vtuple,
        reverse=True,
    )
    bases = args.froms if args.froms is not None else older[: args.keep]

    new_sha = sha256(apk)
    new_size = apk.stat().st_size
    print(f"Yangi: {tag}  {new_size / 1e6:.1f} MB  sha256={new_sha[:12]}...")

    work = Path(tempfile.mkdtemp(prefix="udp_"))
    files = [apk]
    patches = {}
    try:
        new_bytes = apk.read_bytes()
        for base_v in bases:
            base_apk = work / f"{base_v}.apk"
            print(f"\n{base_v}: asosiy APK yuklanmoqda...")
            sh("gh", "release", "download", f"v{base_v}", "--repo", REPO,
               "--pattern", APK_NAME, "--output", str(base_apk), "--clobber")
            print(f"{base_v}: patch yaratilmoqda (1-2 daqiqa)...")
            patch = make_patch(base_apk.read_bytes(), new_bytes)
            pname = f"patch-{base_v}-to-{version}.bin"
            ppath = work / pname
            ppath.write_bytes(patch)

            print(f"{base_v}: patch Dart kodi bilan tekshirilmoqda...")
            out = work / f"check-{base_v}.apk"
            res = subprocess.run(
                [find_dart(), "run", "tool/verify_patch.dart", str(base_apk), str(ppath), new_sha, str(out)],
                cwd=ROOT / "app", text=True, capture_output=True,
            )
            if res.returncode != 0:
                sys.exit(f"Patch tekshiruvi MUVAFFAQIYATSIZ ({base_v}):\n{res.stdout}\n{res.stderr}")
            out.unlink(missing_ok=True)

            patches[base_v] = {
                "name": pname,
                "size": len(patch),
                "from_sha256": sha256(base_apk),
            }
            files.append(ppath)
            print(f"{base_v}: patch {len(patch) / 1e6:.2f} MB (to'liq {new_size / 1e6:.1f} MB) — tekshirildi")
            base_apk.unlink(missing_ok=True)

        manifest = {
            "version": version,
            "apk": {"name": APK_NAME, "sha256": new_sha, "size": new_size},
            "patches": patches,
        }
        mpath = work / "update.json"
        mpath.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        files.append(mpath)

        if args.dry_run:
            print("\n--dry-run: yuklanmadi. Fayllar:", *[str(f) for f in files], sep="\n  ")
            return
        print("\nGitHub'ga yuklanmoqda...")
        out = sh(
            "gh", "release", "create", tag, *map(str, files), "--repo", REPO,
            "--target", "main", "--title", f"Ustun Do'kon {version}", "--notes", args.notes,
        )
        print(out.strip())
    finally:
        if not args.dry_run:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
