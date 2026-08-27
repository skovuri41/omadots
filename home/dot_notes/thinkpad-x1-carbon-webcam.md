# ThinkPad X1 Carbon Gen 14 — webcam fix tracking

Issue: https://github.com/basecamp/omarchy/issues/7776
Related: https://github.com/basecamp/omarchy/issues/6000
PR (gate tightening, doesn't fully fix): https://github.com/basecamp/omarchy/pull/7773

## Root cause

- Camera is a Sony IMX471 on ACPI node `TBE20A0` (status=15, enabled).
- Omarchy's `install/hardware/intel/ipu7-camera.sh` installs `intel-ipu7-camera`
  based on the `OVTI08F4` ACPI node existing — but on this machine it's
  disabled (status=0), so it drives a dead OV08X40 slot and produces no frames.
- `imx471.c` driver + `TBE20A0` sensor binding land in mainline Linux after
  v7.2, so Arch's stock kernel gets it at **7.3**. Not present in 7.1.x/7.2.x.

## Where to check if kernel 7.3 is out

1. https://www.kernel.org — mainline release status, before it reaches Arch.
2. https://archlinux.org/packages/core/x86_64/linux/ — what Arch actually ships.
3. On this machine: `checkupdates | grep ^linux` or just `sudo pacman -Syu`.

Baseline at time of writing: kernel `7.1.8.arch1-3` (2026-08-24).

## Once 7.3 is installed

Re-check camera works out of the box:
```
for d in /sys/bus/acpi/devices/*/; do
  printf '%s %s\n' "$(cat "$d/hid" 2>/dev/null)" "$(cat "$d/status" 2>/dev/null)"
done | grep -iE 'TBE|SONY|OVTI|INT3472|INTC10'
```
`TBE20A0 15` should now have a matching kernel driver bound
(check `journalctl -k -b | grep -i imx471` and test camera in an app).

## Workaround if not waiting for 7.3

- Driver: https://github.com/BenBJD/imx471-dkms (DKMS build of upstream driver)
- Plumbing: https://github.com/ocewers/x1c14-camera-imx471 (libcamera/WirePlumber
  overlay tuned for this exact model)
- Do **not** uninstall `intel-ipu7-camera` first — the overlay retargets it
  (swaps `icamerasrc` → `libcamerasrc`, masks the ISYS-hiding udev rule,
  re-enables the WirePlumber libcamera monitor) rather than replacing it.
