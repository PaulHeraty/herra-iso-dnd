#!/usr/bin/env bash
# Run Godot for a dev check or test and never leave a game window sitting on the screen.
#   tools/run_godot.sh [-t seconds] [-e seconds] <godot args...>
#     -t  hard time limit (default 60)
#     -e  close this long after the first SCRIPT ERROR / Parse Error (default 4; 0 = don't)
#   e.g. HERRA_AUTO_REACT=1 tools/run_godot.sh --path . -s res://tools/godot/test_save.gd
# Prints Godot's output when it ends; exit code = Godot's, 124 = time limit, 125 = closed after
# an error. A dev script that errors before quit() would otherwise keep its window open until the
# time limit. Afterwards every Godot process started during the run is closed (the editor and
# games launched from it are left alone). Run one at a time (a second run would be closed too).
secs=60
grace=4
while [ $# -gt 0 ]; do
	case "$1" in
		-t) secs=$2; shift 2 ;;
		-e) grace=$2; shift 2 ;;
		*) break ;;
	esac
done
G="/c/Godot/Godot_v4.7.2-stable_win64_console.exe"
here="$(cd "$(dirname "$0")" && pwd)"
log="$(mktemp)"
start=$(date +%s)
"$G" "$@" > "$log" 2>&1 &
pid=$!
code=""
err_at=""
while kill -0 "$pid" 2>/dev/null; do
	now=$(date +%s)
	if [ $((now - start)) -ge "$secs" ]; then
		code=124
		echo "run_godot: time limit (${secs} s) reached, closing Godot" >> "$log"
		break
	fi
	if [ "$grace" != 0 ] && [ -z "$err_at" ] && grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
		err_at=$now
	fi
	if [ -n "$err_at" ] && [ $((now - err_at)) -ge "$grace" ]; then
		code=125
		echo "run_godot: script error, closing Godot" >> "$log"
		break
	fi
	sleep 0.25
done
if [ -z "$code" ]; then
	wait "$pid"
	code=$?
fi
powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/close_godot_runs.ps1")" -Since "$start" >> "$log"
wait "$pid" 2>/dev/null
cat "$log"
rm -f "$log"
exit "$code"
