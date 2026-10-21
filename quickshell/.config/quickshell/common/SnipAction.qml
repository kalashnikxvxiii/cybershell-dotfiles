// SnipAction.qml — the snip command builder, UI-free.
//
// Everything that decides what happens to a crop lives here: the action enum
// and the switch that turns a region into a bash script. The region selector
// (phase 2) stays neutral -- it only produces x/y/w/h -- so the two can evolve
// apart.
//
// Coordinates: the region arrives in GLOBAL LOGICAL compositor coordinates,
// exactly what slurp prints and what wf-recorder expects. The crop rectangle
// is derived from it by subtracting the monitor origin and multiplying by the
// monitor scale, because grim writes device pixels. Deriving the factor from
// the monitor's scale rather than from devicePixelRatio keeps this correct on
// mixed-DPI setups where the shell window is not on the captured output.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    enum Action {
        Screenshot,
        Annotate,
        Ocr,
        Search,
        Record
    }

    // ── Configuration ────────────────────────────────────────────────────
    property string saveDir: (Quickshell.env("HOME") || "") + "/Immagini/Screenshots"
    property string annotator: "swappy"          // swappy | satty
    property string uploadEndpoint: "https://uguu.se/upload"
    property string searchEngineUrl: "https://lens.google.com/uploadbyurl?url="
    // The upload endpoint is a public anonymous file host: the crop leaves this
    // machine. The first Search asks for confirmation and records the answer in
    // this file, so the warning survives a shell restart.
    property string consentFile: (Quickshell.env("HOME") || "") + "/.cache/qs-snip/upload-consent"
    // In the per-user runtime dir, not /tmp: the pid in it gets signalled
    property string recordPidFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-snip/recorder.pid"

    // ── Shell quoting ────────────────────────────────────────────────────
    // Returns the value ALREADY wrapped in single quotes. Callers must never
    // add their own quotes around it, which is how nested-quote bugs start.
    function sq(v) {
        return "'" + String(v === undefined || v === null ? "" : v).split("'").join("'\\''") + "'";
    }

    function actionFromName(n) {
        switch (n) {
        case "screenshot": return SnipAction.Action.Screenshot;
        case "annotate":   return SnipAction.Action.Annotate;
        case "ocr":        return SnipAction.Action.Ocr;
        case "search":     return SnipAction.Action.Search;
        case "record":     return SnipAction.Action.Record;
        }
        return -1;
    }

    // region: { x, y, w, h } in global logical coordinates
    // opts:   { action, source, monitorX, monitorY, scale }
    function getScript(region, opts) {
        const o = opts || {};
        const scale = o.scale || 1;
        const src = o.source || "";

        // Crop rectangle in the captured PNG's own device pixels.
        const px = Math.round((region.x - (o.monitorX || 0)) * scale);
        const py = Math.round((region.y - (o.monitorY || 0)) * scale);
        const pw = Math.max(1, Math.round(region.w * scale));
        const ph = Math.max(1, Math.round(region.h * scale));

        // +repage is mandatory: without it the crop offset stays glued to the
        // image and every later operation is displaced by it.
        const crop = `magick ${sq(src)} -crop ${pw}x${ph}+${px}+${py} +repage`;
        // Two distinct cleanup paths exist for the frozen PNG. This one runs
        // once magick no longer needs it; the overlay deletes it on destruction
        // when the selection is cancelled instead.
        const dropSource = src ? `rm -f ${sq(src)}; ` : "";
        const prelude = `set -uo pipefail; `;
        const fail = (msg) => `notify-send -a 'Snip' 'SNIP FAILED' ${sq(msg)}`;

        switch (o.action) {

        case SnipAction.Action.Screenshot:
            return prelude
                + `SAVE_DIR=${sq(root.saveDir)}; mkdir -p "$SAVE_DIR" || exit 1; `
                + `OUT="$SAVE_DIR/screenshot-$(date +%Y-%m-%d_%H.%M.%S).png"; `
                + `${crop} "$OUT" || { ${fail("magick crop failed")}; ${dropSource}exit 1; }; `
                + `wl-copy -t image/png < "$OUT"; ${dropSource}`
                // --action implies --wait: this blocks until the notification is
                // answered or expires, and prints the pressed button's id. The
                // buttons are three lines of bash, no D-Bus listener needed. -t
                // is what guarantees it eventually returns.
                + `ACT=$(notify-send -a 'Snip' 'SCREENSHOT' "$OUT" -i "$OUT" -t 12000 `
                +   `--action='open=Apri' --action='folder=Apri cartella' || true); `
                + `case "$ACT" in open) xdg-open "$OUT" ;; folder) xdg-open "$SAVE_DIR" ;; esac`;

        case SnipAction.Action.Annotate:
            return prelude
                + `SAVE_DIR=${sq(root.saveDir)}; mkdir -p "$SAVE_DIR" || exit 1; `
                + `OUT="$SAVE_DIR/screenshot-$(date +%Y-%m-%d_%H.%M.%S).png"; `
                + `TMP=$(mktemp /tmp/qs-snip-edit-XXXXXX.png) || exit 1; `
                + `${crop} "$TMP" || { ${fail("magick crop failed")}; rm -f "$TMP"; ${dropSource}exit 1; }; `
                + dropSource
                + `${root.annotator} -f "$TMP" -o "$OUT"; rm -f "$TMP"; `
                + `[ -s "$OUT" ] || exit 0; `
                + `wl-copy -t image/png < "$OUT"; `
                + `ACT=$(notify-send -a 'Snip' 'SCREENSHOT ANNOTATO' "$OUT" -i "$OUT" -t 12000 `
                +   `--action='open=Apri' --action='folder=Apri cartella' || true); `
                + `case "$ACT" in open) xdg-open "$OUT" ;; folder) xdg-open "$SAVE_DIR" ;; esac`;

        case SnipAction.Action.Ocr:
            return prelude
                + `TMP=$(mktemp /tmp/qs-snip-ocr-XXXXXX.png) || exit 1; `
                // The 300% upscale is what makes tesseract usable on UI-sized text.
                + `${crop} -colorspace gray -type grayscale -contrast-stretch 0 -resize 300% "$TMP" `
                +   `|| { ${fail("magick preprocess failed")}; rm -f "$TMP"; ${dropSource}exit 1; }; `
                + dropSource
                // Zero configuration: whatever tesseract has installed is used.
                + `LANGS=$(tesseract --list-langs 2>/dev/null | awk 'NR>1 && $1!="osd" {print $1}' | tr '\\n' '+' | sed 's/+$//'); `
                + `if [ -n "$LANGS" ]; then TEXT=$(tesseract "$TMP" stdout -l "$LANGS" 2>/dev/null); `
                + `else TEXT=$(tesseract "$TMP" stdout 2>/dev/null); fi; rm -f "$TMP"; `
                + `TEXT=$(printf '%s' "$TEXT" | sed -e 's/[[:space:]]*$//' -e '/./,$!d'); `
                + `if [ -z "$TEXT" ]; then notify-send -a 'Snip' 'OCR' 'Nessun testo riconosciuto'; exit 0; fi; `
                + `printf '%s' "$TEXT" | wl-copy; `
                + `notify-send -a 'Snip' 'OCR' "$TEXT"`;

        case SnipAction.Action.Search:
            return prelude
                + `CONSENT=${sq(root.consentFile)}; `
                + `if [ ! -f "$CONSENT" ]; then `
                +   `ACT=$(notify-send -a 'Snip' 'REVERSE IMAGE SEARCH' `
                +     sq(`Il ritaglio verra caricato su ${root.uploadEndpoint} (host pubblico anonimo) e il link aperto su Google Lens.`)
                +     ` -u critical -t 20000 --action='ok=Ho capito, procedi' --action='no=Annulla' || true); `
                // Timing out counts as refusal: the default must never upload.
                +   `if [ "$ACT" != "ok" ]; then ${dropSource}exit 0; fi; `
                +   `mkdir -p "$(dirname "$CONSENT")" && date -Is > "$CONSENT"; `
                + `fi; `
                + `TMP=$(mktemp /tmp/qs-snip-search-XXXXXX.png) || exit 1; `
                + `${crop} "$TMP" || { ${fail("magick crop failed")}; rm -f "$TMP"; ${dropSource}exit 1; }; `
                + dropSource
                + `URL=$(curl -sf --max-time 30 -F files[]=@"$TMP" ${sq(root.uploadEndpoint)} | jq -r '.files[0].url // empty'); `
                + `rm -f "$TMP"; `
                + `if [ -z "$URL" ]; then ${fail("upload non riuscito")}; exit 1; fi; `
                + `xdg-open ${sq(root.searchEngineUrl)}"$URL"`;

        case SnipAction.Action.Record: {
            // wf-recorder wants GLOBAL LOGICAL coordinates, not the scaled pixel
            // rect the crop uses -- this is the one action that ignores `scale`.
            const gx = Math.round(region.x), gy = Math.round(region.y);
            const gw = Math.max(1, Math.round(region.w)), gh = Math.max(1, Math.round(region.h));
            return prelude
                + `PIDF=${sq(root.recordPidFile)}; SAVE_DIR=${sq(root.saveDir)}; `
                + dropSource
                // Signalled only if it is still wf-recorder: a stale file
                // can name a pid that has since been reused by anything
                + `REC=$(cat "$PIDF" 2>/dev/null); `
                + `if [ -n "$REC" ] && [ "$(cat "/proc/$REC/comm" 2>/dev/null)" = wf-recorder ]; then `
                +   `kill -INT "$REC"; rm -f "$PIDF"; `
                +   `notify-send -a 'Snip' 'RECORDING' 'stop'; exit 0; fi; `
                + `mkdir -p "$SAVE_DIR" || exit 1; `
                + `OUT="$SAVE_DIR/record-$(date +%Y-%m-%d_%H.%M.%S).mp4"; `
                + `wf-recorder -g "${gx},${gy} ${gw}x${gh}" -f "$OUT" & `
                + `mkdir -p "$(dirname "$PIDF")" && echo $! > "$PIDF"; `
                + `notify-send -a 'Snip' 'RECORDING' 'in corso — stesso tasto per fermare'`;
        }
        }

        console.warn("[SnipAction] unknown action:", o.action);
        return "";
    }

    function getCommand(region, opts) {
        const s = root.getScript(region, opts);
        return s ? ["bash", "-c", s] : undefined;
    }

    // ── Dispatch ─────────────────────────────────────────────────────────
    // The one place a snip is actually executed. SnipState calls this, both
    // from the overlay and from the keybind file channel.
    function run(region, opts) {
        const cmd = root.getCommand(region, opts);
        if (cmd)
            Quickshell.execDetached(cmd);
    }
}
