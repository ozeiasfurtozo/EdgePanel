# Hardware validation checklist

This checklist requires a Mac with the physical XENEON EDGE and its USB touch controller. The automated tests cover data persistence, ZIP validation, and coordinate math; they do not prove live touch or macOS permission behavior.

## Touch and display

- Connect USB and video in both orders. Confirm the editor lists the intended display and that the dashboard appears only there.
- With the dashboard on the XENEON, confirm the macOS menu bar is fully covered across its top edge (including when the pointer reaches it), while the menu bar and EdgePanel icon remain visible on the main monitor. Confirm the bar returns on the XENEON when the dashboard closes.
- Select the display, enable touch, grant Input Monitoring and Accessibility, and confirm the touch status changes to **Controller connected; waiting for touch**. Tap all five calibration targets. Confirm clicks stay on the XENEON, the status changes to **Touch redirected to the XENEON**, and the normal pointer returns after release.
- Drag a tile or a test control. Unplug USB during a held drag; verify the mouse button is released.
- Move the XENEON to the left, right, above, and below the primary display. Repeat at native and scaled resolutions, and after rotating the display.
- Sleep/wake and reconnect. Confirm touch resumes only on the selected display and no input goes to the main screen.
- Test with another touch utility already claiming the HID device. Confirm EdgePanel reports the conflict.
- Deny and later revoke Accessibility and Input Monitoring, then retry. Confirm the editor explains that macOS may still handle uncaptured touches and that the dashboard remains usable by mouse.

## Dashboard and widgets

- Add, drag, resize, and remove each native tile. Confirm overlap is prevented and settings survive relaunch.
- Create two profiles and multiple pages; switch between them in the editor and EdgePanel menu-bar icon. Close the editor and reopen it from the Dock.
- Test launcher with an installed `.app`, timer controls, clock, CPU/RAM values, network traffic, and a web URL.
- Disconnect the video display while leaving USB connected. Confirm the dashboard closes and touch does not target another monitor.
- Record the original **Hardware brightness**, move the slider to a different value, and confirm this only previews the value. Click **Apply**, then restore the original value and apply again. Confirm the XENEON's physical luminance changes, the other monitor does not, and the value reloads after reopening the editor. Change brightness externally and use the refresh button. Unplug the XENEON with an unapplied value and confirm no other monitor receives a command.

## Imported packages

- Import a simple iCUE clock and a widget using color/text/slider controls. Confirm settings update the rendered widget and persist.
- Import a widget using Sensors 1.0 for CPU/RAM usage. Confirm live values and that unsupported GPU/temperature IDs are absent.
- Import a widget requiring Media or Stream Deck. Confirm it is marked incompatible before activation.
- Test a package requesting a network domain; confirm no request succeeds before enabling that domain, and that an unrequested domain remains blocked.
- Test corrupt ZIPs, path traversal, symbolic links, oversized payloads, and duplicate names.

## Public DMG

- Install the signed and notarized DMG on a separate clean Apple Silicon Mac with macOS 14.
- Confirm Gatekeeper accepts it and the permissions attach to the installed app across relaunch and update.
- Re-run the touch and imported widget checks on the installed app.
