# Close Godot processes started at or after unix time -Since (left over from a dev/test run),
# never the editor (--editor) or games the editor launched (--remote-debug). Used by run_godot.sh.
param([long]$Since)
$s = [DateTimeOffset]::FromUnixTimeSeconds($Since).LocalDateTime.AddSeconds(-1)
Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" |
	Where-Object { $_.CreationDate -ge $s -and $_.CommandLine -notmatch '--editor|--remote-debug' } |
	ForEach-Object {
		Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
		Write-Output ("run_godot: closed a leftover Godot window (pid {0})" -f $_.ProcessId)
	}
