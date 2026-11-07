# Slow shutdown: plasmashell hangs on exit

Investigation notes, started 2026-11-07. **Status: waiting for a live backtrace of the hang.**

## Symptom

Shutdown/reboot takes ~41 s instead of ~2 s.

| Boot (as of 2026-11-07) | Session length | Shutdown time | plasmashell hung? |
|---|---|---|---|
| -5 | ?        | 41.2 s | yes |
| -4 | ~9 h     | 41.3 s | yes |
| -3 | ~22 min  | 1.8 s  | no  |
| -1 | ~3.3 h   | 41.0 s | yes |

The hang seems to need a longer session; the short session shut down cleanly.

## What the journal shows

```
systemd[user]: Stopping plasma-plasmashell.service ...        (t)
plasmashell: IPP_INTERNAL_ERROR: clearing cookies and reconnecting   (printer applet, x4)
plasmashell: QObject::disconnect: Unexpected nullptr parameter
kwin_wayland: PipeWire remote error: connection error
  ... 40 s of nothing ...
plasma-plasmashell.service: State 'stop-sigterm' timed out. Aborting.   (t+40)
Killing process (plasmashell) with signal SIGABRT
```

- `TimeoutStopUSec=40s` for `plasma-plasmashell.service`: that is the whole delay.
- Everything else in the shutdown finishes in ~1 s.
- Dumps from the newer hangs were **not** saved (`systemd-coredump: Failed to send coredump datagram: Connection reset by peer`), because the coredump socket is already gone during shutdown.

Commands used:
```bash
journalctl -b -1 -o short-monotonic | grep -iE "timed out|SIGKILL|SIGABRT"
journalctl -b -1 -o short-monotonic | grep plasmashell
coredumpctl list plasmashell
```

## Crash dump analysis (core from 2026-11-05 22:42, PID 3901, plasma-workspace 6.8.1)

Main thread, stuck in teardown:
```
QThread::wait
QQuickPixmapReader::~QQuickPixmapReader     <- waits forever for the image-loader thread
QObjectPrivate::deleteChildren
PlasmaQuick::DialogBackground::~DialogBackground
QQuickWindow::~QQuickWindow
ToolTipArea::~ToolTipArea                   <- a panel/tray tooltip being destroyed
main
```

So the Qt Quick image loader thread doesn't finish. **Unknown: what that thread is blocked on.**
I couldn't resolve its stack because the libraries in that core have since been updated (build-id mismatch).

Suspects, based on what's loaded and logged just before the hang:
- print-manager applet (`libkcups`, IPP errors right before the hang)
- media controller / KPipeWire (PipeWire error right before the hang)
- KIO thumbnail/icon loading through an image provider
- mesa/gallium GPU thread

## Versions

- plasma-workspace 6.8.2 / libplasma 6.8.2 (installed 2026-11-06 18:39). **The hang still happened after this update** (boot -1).
- qt6-qtdeclarative 6.11.2, kf6 6.31.0, kernel 7.2.15-300.fc45

## Setup done so far

- Debug symbols prefetched into `~/.cache/debuginfod_client` (~1 GB) for plasmashell, Qt6 Core/Gui/Qml/Quick,
  libPlasma, libPlasmaQuick, KIO, libkcups, pipewire, libgallium, libcorebindingsplugin, and libc.
  These need re-fetching if those packages are updated.
- `ptrace_scope=0`, gdb and eu-stack are installed, and `DEBUGINFOD_URLS` points to Fedora.
- **Not installed yet:** the capture hook below (the user installs it manually).

## Next step: capture a live backtrace

### Option A: automatic capture at shutdown (recommended)

```bash
mkdir -p ~/.local/bin ~/.config/systemd/user/plasma-plasmashell.service.d
cat > ~/.local/bin/plasmashell-hang-capture.sh <<'EOF'
#!/bin/sh
pid="$1"; [ -n "$pid" ] || exit 0
kill -TERM "$pid" 2>/dev/null
for i in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$pid" 2>/dev/null || exit 0; sleep 0.5; done
out="$HOME/plasmashell-hang-$(date +%F_%H%M%S).txt"
{
  echo "plasmashell $pid hung on SIGTERM at $(date)"
  for t in /proc/"$pid"/task/*; do echo "$(basename $t) $(cat $t/comm) $(cat $t/wchan)"; done
  timeout 25 gdb -p "$pid" -batch -nx -ex 'set debuginfod enabled on' \
      -ex 'set pagination off' -ex 'info threads' -ex 'thread apply all bt'
} > "$out" 2>&1
sync
EOF
chmod +x ~/.local/bin/plasmashell-hang-capture.sh
printf '[Service]\nExecStop=%%h/.local/bin/plasmashell-hang-capture.sh $MAINPID\n' \
  > ~/.config/systemd/user/plasma-plasmashell.service.d/hang-capture.conf
systemctl --user daemon-reload
```

Use the machine for a few hours, then shut down. The output lands in `~/plasmashell-hang-*.txt`.
To remove the hook: `rm ~/.config/systemd/user/plasma-plasmashell.service.d/hang-capture.conf && systemctl --user daemon-reload`.

### Option B: reproduce on demand (the panel restarts)

```bash
time systemctl --user restart plasma-plasmashell
# if it hangs, from another terminal:
gdb -p $(pgrep plasmashell) -batch -ex 'set pagination off' -ex 'thread apply all bt' > ~/hang.txt
```

### Option C: find the widget

Remove the printer widget (and/or the media controller) from the system tray, then check whether long-session shutdowns become clean.

## When resuming

1. `ls ~/plasmashell-hang-*.txt` and read the newest file.
2. In it, find the thread with `QQuickPixmapReader::run`, `QQuickImageProvider`, or `QQuickImageResponse` in its stack.
   Whatever that thread is blocked in (cups, KIO, D-Bus, PipeWire, GL) is the culprit.
3. Also check `journalctl -b -1 | grep -i plasmashell` and redo the shutdown-time table above.
4. Then pick a fix: remove or replace the offending widget, file a KDE bug with the backtrace, and/or
   add a workaround drop-in (`TimeoutStopSec=5s` in a **separate** file, e.g. `timeout.conf`, but only after
   capturing is done, because the capture script needs about 30 s of the stop window).
