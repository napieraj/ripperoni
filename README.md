# 🍕 ripperoni

*A POSIX shell CLI that makes your physical media... disappear onto a hard drive. Bada bing, bada boom.*

Look, you got a disc. You want the files off the disc. You don't wanna ask a million questions, and you don't wanna click through twelve different GUIs. ripperoni is the middleman. It figures out what kind of plastic you jammed into your drive and calls the right guy (`makemkvcon`, `cyanrip`, `redumper`) to take care of it.

We don't reinvent the wheel here. We just make sure everyone pays their respects to the same boss.

## Why "ripperoni"

Because "rip" was taken by guys who don't respect the `$PATH`, and "disc-ripper-9000" sounds like a wiretap the Feds would install on your 2003 gateway PC. ripperoni is memorable, typeable, and commands respect.

## The Racket (What it does)

You put a disc in. You type `ripperoni`. We handle the rest. No questions asked.

```text
$ ripperoni
[info] drive: /dev/sr0
[info] state: ready
[info] type: bd-uhd
[info] label: GOODFELLAS
[info] output: /home/you/media/rips/bluray/GOODFELLAS
[info] handler: bd
[info] libredrive: enabled
... (makemkvcon does the heavy lifting) ...
[info] rip complete. the job is done.
[info] paper trail secured in GOODFELLAS.sha256
```

That's the whole operation. One command. No flags. No wizard interrogating you about codec profiles when you just want to secure a backup of _The Godfather_ and go to sleep.

## The Operation (What it supports)

| **stuff**   | **capo** | **muscle**                                      |
| ----------- | -------- | ----------------------------------------------- |
| Blu-ray     | `bd`     | `makemkvcon`                                    |
| UHD Blu-ray | `bd`     | `makemkvcon` (requires the LibreDrive loophole) |
| DVD-Video   | `dvd`    | `makemkvcon`                                    |
| Audio CD    | `cd`     | `cyanrip`                                       |
| Data disc   | `data`   | `dd` (or `ddrescue` when `RIPPERONI_RESCUE=1`)  |
| Game disc   | `game`   | 🚧 prints the redumper command and walks away   |

The game handler is a stub right now. Game dumping is a very specific racket and we don't wanna step on their toes yet. Use redumper directly for now.

## Subcommands

```
ripperoni                      rip whatever's loaded (the hit)
ripperoni drives               list optical drives
ripperoni state                see what the drive is hiding
ripperoni eject                open the trunk
ripperoni close                shut the trunk
ripperoni wait --for ready     lay low until the target is visible
ripperoni wiretap              stream state changes as JSON
ripperoni doctor               health check the family
ripperoni config               print resolved config
```

## Keeping Tabs

Ripperoni tracks what the drive is physically doing.

- **`unknown`** — Guy's not talking. Maybe he's unplugged, maybe he's sleeping with the fishes.
- **`open`** — Drive's open. Shut it.
- **`loading`** — Drive is spinning up.
- **`empty`** — Nobody home. Feed it.
- **`ready`** — Go time.
- **`busy`** — Something is already working over the device.
- **`empty-or-open`** — macOS only. Apple talks to the cops too much _(see **The Apple Snitch Issue** below)_.

**The Apple Snitch Issue:** Linux relies on the `CDROM_DRIVE_STATUS` ioctl. Apple's `drutil` is a useless rat that can't tell an open tray from an empty one. Downstream tooling should treat macOS surveillance events with extreme suspicion until we vibe code a Swift-based IOKit bypass.

## Getting Made

_(macOS/Linux dependencies remain the same. Compile `makemkvcon` from source on Linux because DRM is a racket. See https://forum.makemkv.com/)_

```sh
# ... standard git clone / symlink setup ...
mkdir -p ~/.config/ripperoni
cp ~/src/ripperoni/share/templates/config ~/.config/ripperoni/config
$EDITOR ~/.config/ripperoni/config

ripperoni doctor
```

Run `ripperoni doctor`. He will tell you what's what. Fix the problem, run it again. When he gives you the nod, feed it a disc.

### Environment overrides

These override or supplement the config file (see also `ripperoni help`):

| Variable | Effect |
| -------- | ------ |
| `RIPPERONI_OUTPUT_ROOT` | Default output directory |
| `RIPPERONI_DRIVE` | Device path (Linux, e.g. `/dev/sr1`) or drutil drive number (macOS, e.g. `2`) |
| `RIPPERONI_CONFIG` | Path to the shell config file |
| `RIPPERONI_RESCUE` | Set to `1` so the data handler uses `ddrescue` instead of `dd` |
| `RIPPERONI_MAKEMKV_DISC` | Force MakeMKV’s `disc:N` index (e.g. `0`) if automatic mapping is wrong |

Post-rip **stream** checks (`ffmpeg` / `flac`) honor `verify=0` in the config or `--no-verify` on the command line. Checksum sidecars are still written after a successful rip.

## Omertà (Design principles)

1. **Detect, don't ask.** The tool figures it out. Flags are for overriding, not interrogations.
2. **Dispatch, don't reimplement.** ripperoni is the boss. It delegates.
3. **One command, one disc.** We do things properly here.
4. **Idempotent output.** Same disc → same stash location.
5. **Cook the books.** Every job leaves a `.sha256` paper trail so future-you knows what happened when the bitrot mafia comes knocking.
6. **Fail loud.** Missing tool? Drive on fire? We make a scene and exit (non-zero).

## Things we don't get involved in

- ❌ **No transcoding.** HandBrake is a friend of ours. Pass the file to him.
- ❌ **No queueing.** One job at a time. Don't get greedy.
- ❌ **No Windows.** We don't associate with rats. Windows users talk. You think we're gonna run a quiet operation on an OS that comes out of the box wearing a wire to Redmond? Forget about it.
- ❌ **No auto-anything.** No moves are made without direct command. Nobody goes rogue.

## Known Quirks

- If `ripperoni doctor` says the crew is ready but the rip still fails... it's the wire. It is always the fucking wire. Change the wire before you come crying.

## License

[MIT No Attribution (0-clause MIT)](LICENSE) — do whatever you want with it. If it eats your disc, that's between you and the disc.
