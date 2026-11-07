# fedora-kde-setup

Scripts that install and set up a Fedora KDE Plasma machine.

## Everything at once

```bash
./run-all.sh
```

Runs every `install-*` and `setup-*` script in the right order (see
`./run-all.sh --list`). Run it from inside a Plasma session as your normal user;
it asks for your sudo password once.

Every script is safe to run again: it skips what's already done and only
changes what's missing or out of date. If a step fails, the rest still run and
the failures are listed at the end.

```bash
./run-all.sh --from install-vscode           # carry on from a step
./run-all.sh --only install-steam setup-git  # just these steps
./run-all.sh --skip install-steam            # everything but these
```

## One thing at a time

Each script also runs on its own, e.g. `./install-steam.sh`. Everything an
install script adds can be undone with the matching script in `remove/`.

When you add a new `install-*` or `setup-*` script, add it to `STEPS` in
`run-all.sh` (it warns about scripts that aren't listed).
