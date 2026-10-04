#!/usr/bin/env bash
# ai-voice.sh - push-to-talk dictation for the AI chat composer.
#
# `record` captures the default source until `stop` is called, then prints the
# transcript on stdout. Recording and transcription are the SAME process on
# purpose: the caller reads the text as that process' output and needs no
# second channel back.
set -uo pipefail

RUN="${XDG_RUNTIME_DIR:-/tmp}/qs-ai-voice"
WAV="$RUN/take.wav"
PIDF="$RUN/rec.pid"
MODEL_DIR="$HOME/.cache/whisper"
MODEL="${QS_WHISPER_MODEL:-$MODEL_DIR/ggml-base.bin}"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
LANG_CODE="${QS_WHISPER_LANG:-auto}"

whisper_bin() {
    for c in whisper-cli whisper-cpp whisper; do
        command -v "$c" >/dev/null 2>&1 && { echo "$c"; return 0; }
    done
    return 1
}

case "${1:-}" in
record)
    mkdir -p "$RUN"
    rm -f "$WAV"
    # 16 kHz mono is what whisper.cpp wants natively; anything else costs a
    # resampling pass before it can even start
    pw-record --rate 16000 --channels 1 --format s16 "$WAV" &
    REC=$!
    echo "$REC" > "$PIDF"
    wait "$REC" 2>/dev/null
    rm -f "$PIDF"

    # A take shorter than a WAV header plus a few frames has nothing in it
    [ -s "$WAV" ] || exit 0

    BIN=$(whisper_bin) || {
        echo "whisper.cpp not installed: pacman -S whisper-cpp" >&2; exit 1; }

    if [ ! -f "$MODEL" ]; then
        mkdir -p "$MODEL_DIR"
        # Download to a .part first: an interrupted fetch must not leave a
        # truncated file that looks like a valid model on the next run
        curl -fsSL -o "$MODEL.part" "$MODEL_URL" \
            && mv "$MODEL.part" "$MODEL" || {
            echo "model download failed" >&2; rm -f "$MODEL.part"; exit 1; }
    fi

    # -nt no timestamps, -np no progress chatter: stdout is only the words.
    # The bracketed tags are whisper's non-speech markers ([ Music ],
    # [BLANK_AUDIO], (silence)): they are not dictation, so they are dropped
    "$BIN" -m "$MODEL" -f "$WAV" -l "$LANG_CODE" -nt -np 2>/dev/null \
        | tr '\n' ' ' \
        | sed -e 's/\[[^]]*\]//g' -e 's/([^)]*)//g' \
              -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//'
    ;;
stop)
    [ -f "$PIDF" ] || exit 0
    # SIGINT, not SIGKILL: pw-record patches the WAV header on the way out
    kill -INT "$(cat "$PIDF")" 2>/dev/null
    ;;
*)
    echo "usage: ai-voice.sh record|stop" >&2; exit 2 ;;
esac
