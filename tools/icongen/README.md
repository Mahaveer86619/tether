# icongen

Draws the app icon from code so it stays crisp at every size.

```sh
cd tools/icongen && go run . && cp icon.png icon_foreground.png ../../app/assets/icon/
cd ../../app && dart run flutter_launcher_icons
```

Writes `icon.png` (full rounded tile), `icon_foreground.png` (mark only, inside the adaptive-icon safe zone) and `preview.png` (launcher sizes side by side).
