# MiSans System Font

KernelSU module that replaces Roboto with **MiSans** system-wide on PixelOS —
apps, the PixelOS interface and the status bar clock.

Straight strokes instead of rounded ones, Latin and Cyrillic from a single
file, and a weight slider that reaches every app.

## Requirements

- PixelOS on Xiaomi 13 (fuxi) or another device with the PixelOS gsans overlay
- KernelSU / Magisk with **HybridMount** — the interface substitution runs on
  its VFS backend
- A reboot after changing the weight

The interface substitution can be turned off, see below. Everything else works
without HybridMount.

## Install

Flash the release zip in KernelSU or Magisk, then reboot.

```
su -c 'sh /data/adb/modules/misans/action.sh'
```

prints the current state.

## Weight

KernelSU → MiSans System Font → web UI. Slider 0…300, presets, a weight
mapping table and a "save and reboot" button.

```
0   → regular text at 400
100 → 500
200 → 600
300 → 700, the top of the MiSans axis
```

From a shell:

```bash
su -c 'sh /data/adb/modules/misans/action.sh set 150'
```

A reboot is required. The font configuration is read once at boot.

## How it works

Three parts.

**The font.** `MiSansLatinVF.ttf` from the stock Xiaomi 13 `product` partition
is installed as `/system/fonts/Roboto-Regular.ttf`. Only the file changes, the
name stays, so the system configuration remains valid by construction. The
PostScript name is patched to `Roboto-Regular` because `FontListParser` derives
it from the filename and the font map fails to resolve otherwise.

`sans-serif`, `roboto`, `sans-serif-condensed` and the system fallback all
follow from that one file.

**The weight shift** is written into the font configuration at every boot.
`post-fs-data.sh` copies the templates in `templates/` and adds the shift to
each `wght` value.

It is not `Settings.Secure.FONT_WEIGHT_ADJUSTMENT`. That setting is applied in
`TextView.setTypeface()` only, so apps that pick a font outside that path never
see it, and it can only add weight — on top of an existing shift the slider
cannot go lower, which is what made it look broken.

**The interface and clock** are substituted through `/product`, via VFS rules:

```
/product/etc/fonts_customization.xml       → generated config
/product/fonts/GoogleSans-Regular.ttf      → MiSans
/product/fonts/GoogleSansFlex-Regular.ttf  → MiSans
/product/fonts/GoogleSansClock-Regular.ttf → MiSans
```

### Why /product is involved

PixelOS declares the interface font in a runtime overlay in `/product`:

```xml
<string name="config_bodyFontFamily">google-sans-text</string>
<string name="config_clockFontFamily">google-sans-clock</string>
```

A family defined in `/system/etc/fonts.xml` under the same name is silently
dropped, because the OEM customization wins:

```java
// FontListParser.java
if (!oemNamedFamilies.containsKey(name)) {
    // The OEM customization overrides system named family.
```

Three other routes are closed as well:

- overriding the resource needs an RRO overlay, which also lives in `/product`
- substituting the file through updatable fonts needs a PKCS#7 signature from
  `/product/etc/security/fsverity/gms_fsverity_cert.der`, a Google key
- `extra_mount` in HybridMount refuses `/product`, because it requires no
  matching `/system` entry and `/system/product` is a symlink

VFS rules redirect paths in the kernel and are not subject to that check.

### Why GoogleSansFlex matters

`GoogleSansFlex-Regular.ttf` holds **535 glyphs**: Latin and digits, with no
Cyrillic at all. The interface asks for `variable-*` families, all of which use
that file. Without replacing it, a single line mixes two fonts — Latin from
stock Google Sans Flex, Cyrillic falling through to MiSans:

```
status bar clock   digits thin, everything else bold
app drawer         Russian names bold, English names thin
shade date         "Вс окт." bold, "11" thin
```

### How the generated config is built

`build_customization.py` turns the stock `fonts_customization.xml` into a
template. It repoints faces by **file**, not by family name — the interface
asks for 18 `variable-*` families, and listing them by hand means forgetting
one. Axes MiSans does not have (`GRAD`, `opsz`, `wdth`) are dropped. Italic
faces stay on `GoogleSans-Italic.ttf`, since MiSans has no italic file.

```bash
python3 build_customization.py fonts_customization.xml templates/fonts_customization.xml
```

Run it against a `fonts_customization.xml` from your ROM.

## Why post-fs-data

metamodule runs its mount script after the module scripts:

```
ksud::cli: command: PostFsData
  exec <module>/post-fs-data.sh            ← here
  ksud::metamodule: Executing mount script
```

So the configs can still be edited, and the mount picks up the changed files.
Checking the overlay at this point would be pointless — it does not exist yet.

## One detail without which the device does not boot

Everything shipped in `/system` must carry the SELinux context
`system_file`. Files pushed over adb keep `shell_data_file`, magic mount
serves them under that context, and zygote cannot read the config:

```
avc:  denied { read } for name="fonts.xml" dev="overlay"
      scontext=u:r:zygote:s0
E SystemFonts: FileNotFoundException: /system/etc/fonts.xml: EACCES
```

`FontManagerService_create` then fails, `serviceStarted.complete(null)` is never
called, `mServiceStarted.join()` blocks forever and the watchdog kills
SystemServer in a loop.

```bash
ls -lZ /system/fonts/Roboto-Regular.ttf   # expect system_file
```

`customize.sh` sets the context on install and `service.sh` repairs it later.
`sepolicy.rule` is a fallback in case `chcon` does not take.

## Turning the interface substitution off

```
su -c 'sh /data/adb/modules/misans/action.sh unify off'
```

Reboot to apply. The interface and clock return to Google Sans, apps stay on
MiSans. There is also a toggle in the web UI.

VFS rules are runtime-only and never written to disk, so a reboot is always a
way back to stock even without the switch.

## Glyph coverage

MiSans is a Latin subset: no vulgar fractions, thin Greek and Cyrillic
extension coverage, and little Latin Extended Additional. The interface font
Google Sans Flex is worse — 535 glyphs, Latin and digits, no Cyrillic at all.
Glyphs they do not draw fall back.

`system/fonts/RobotoStatic-Regular.ttf` is RobotoStatic, already present in
stock `/system`, subset to the codepoints that MiSans lacks and nothing else
in the fallback chain provides. It is last in the chain, so it is consulted
only when no other font has the glyph. `build_donor.py` regenerates it.

**Reading the chain is the subtle part.** Almost every font in
`font_fallback.xml` looks like it belongs to the general fallback, but only
fonts in nameless `<family>` blocks do, plus the first named family:

```java
// FontListParser.readFamilies
if (name == null) { families.add(family); }
else if (firstFamily) { families.addAll(namedFamilyList.getFamilies()); }
```

Fonts inside `<family name="source-sans-pro">` sit in a map keyed by name and
are never consulted for `sans-serif`. Counting all 198 files in the file as
the chain makes the donor far too small — it drops the vulgar fractions Gboard
shows on the digit keys.

## Known limits

**The first quick settings shade expand after boot can lag.** minikin opens
fallback fonts lazily, on first use, on the UI thread. The quick settings
header is built when the shade first opens, and laying out its text opens the
donor. With the interface substitution on it is noticeable for roughly half a
second.

A smaller donor avoids it, but only when the interface substitution is off.
With it on the lag is there either way, so the module ships full coverage
rather than trading it for speed that does not materialise.

**Apps with their own bundled font** are not affected. An app that ships a
`.ttf` in assets and asks for it by name bypasses the configuration. Stock
HyperOS behaves the same way.

**Google Play Services** pulls some fonts through its own `FontsProvider`.

**`sans-serif-monospace` and `sans-serif-smallcaps`** stay on Roboto: they use
different files. `sans-serif-monospace` resolves to `DroidSansMono.ttf`,
which is left alone on purpose — a clock needs fixed-width digits.

**Italic** stays Google Sans, because MiSans has no italic file.

## Tests

```bash
node test_webui.js
```

Runs the web UI in node with stubbed `document` and `ksu`, presses every
button and checks the status text. `node --check` only catches syntax errors;
a lost `+` once made the save button throw while the check passed.

## Licence

Module code: MIT, see `LICENSE`.

The MiSans font is Xiaomi's property and is redistributed with their firmware.
This module carries no licence for it and is intended for devices that already
run the stock Xiaomi ROM. It is not a ROM build and does not modify system
binaries.
