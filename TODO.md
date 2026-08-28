# TODO

## Explore Quickshell on Fedora (bare metal)

[Quickshell](https://quickshell.org/) is a QtQuick/QML toolkit for **building** a
Wayland desktop shell — status bars, launchers, lock screens, notification
daemons, OSD popups — as declarative QML rather than as a C rewrite. It is the
widget layer behind several Hyprland setups, and one of the projects the
[Omacom Foundation sponsors](https://omarchy.org/sponsorships/) alongside
Hyprland and mise.

**Not applicable to WSL.** Quickshell draws its surfaces through the
`wlr-layer-shell` protocol, which is how a client asks a wlroots-style
compositor for a panel/overlay layer. Under WSLg you are a client of Microsoft's
own compositor, which does not expose layer-shell — and there is no compositor
of your own to decorate in the first place. Nothing to evaluate there.

**Where it belongs:** `setup-fedora/` on bare metal, where a real Wayland
compositor is in play.

### Questions to answer
- [ ] Which compositor on bare-metal Fedora — Hyprland, or stay on GNOME/KDE?
      Quickshell needs a wlroots-style compositor for layer-shell.
- [ ] Is it packaged for Fedora, or is it a COPR / build-from-source job?
- [ ] What would it actually replace — waybar, wofi, swaync, swaylock?
- [ ] Does it earn its keep over waybar, given it means writing QML?
- [ ] If yes: does it belong in `setup-fedora/packages/apps.sh`, or its own
      `packages/desktop.sh`?

### Related
- `setup-fedora/` is currently the only bare-metal Fedora target in this repo
  and has no README yet.
