## cursor-behavior-for-xcode

Open the currently active file from Xcode in Cursor at the same line and column. This repo contains a small shell script you can wire up to an Xcode Behavior and trigger via a keyboard shortcut.

### What it does
- Detects the active document in Xcode (the foremost window) and reads the caret position.
- Finds the nearest Xcode project root by searching up for a `.xcodeproj` or `.xcworkspace`.
- Launches Cursor on that project root and jumps straight to the file at the exact `line:column`.

### Requirements
- macOS with Xcode 14/15/16.
- Cursor installed, with the `cursor` command available in your `PATH`.
  - In Cursor, run: Command Palette → “Shell Command: Install ‘cursor’ command in PATH”.
- On first run, macOS may prompt for Automation/Accessibility permissions.

### Install
1. Clone or download this repo.
2. Make the script executable:
```
chmod +x /absolute/path/to/open-in-cursor.sh
```
3. Optional (recommended): Move or symlink it to a stable location, e.g. `~/bin/open-in-cursor.sh`.

### Configure Xcode Behavior (keyboard shortcut)
1. Open Xcode → Settings… → Behaviors.
2. Click the + button to create a new behavior (e.g., “Open in Cursor”).
3. Assign a keyboard shortcut.
4. In the behavior details, check “Run” and choose “Command…”. Point it at your `open-in-cursor.sh`.

Now, when you press the shortcut in Xcode, Cursor will open the project and jump to the same cursor position.

### Usage notes
- Save first: The script requires the file to be saved (it intentionally warns when the window title shows “Edited”).
- Multiple windows: It targets the foremost Xcode window and resolves the document by the name in the title bar.
- Project detection: If no `.xcodeproj`/`.xcworkspace` is found up the tree, it falls back to the file’s directory.

### How it works
It adjusts `PATH` so Xcode’s restricted environment can find the Cursor CLI, asks Xcode (via AppleScript) for the current document and caret position, then runs Cursor with `--goto`:

```1:20:open-in-cursor.sh
# ... existing code ...
# Xcode behaviors have limited PATH - add common Cursor locations
export PATH="/usr/local/bin:/opt/homebrew/bin:/Applications/Cursor.app/Contents/Resources/app/bin:$PATH"
# ... existing code ...
```

```58:98:open-in-cursor.sh
-- ... existing code ...
-- Get the selected character range directly (loc is 0-based)
set {loc, len} to selected character range of current_document
-- Compute line and column from the document text and prefix
return (lineNum as string) & ":" & (colNum as string)
-- ... existing code ...
```

```157:164:open-in-cursor.sh
# ... existing code ...
# Open the project directory in Cursor, then navigate to the specific file, line, and column
cursor "$project_root" --goto "$file_path:$line_number:$column_number"
# ... existing code ...
```

### Troubleshooting
- **“cursor: command not found”**: Install the Cursor CLI from Cursor’s Command Palette, or ensure your PATH includes the Cursor binary directory. The script already adds common locations to PATH.
- **“Please save the current document…”**: Save the file in Xcode before triggering the behavior.
- **“No matching document found” / “No Xcode window found”**: Ensure the file is open and Xcode has a frontmost window.
- **Nothing happens on first run**: macOS may prompt for Automation permissions (Xcode/osascript controlling Xcode). Approve prompts in System Settings → Privacy & Security → Automation/Accessibility.
- **Logs**: Output is mirrored to Console.app with subsystem/tag `open-in-cursor`. Open Console and search for `open-in-cursor`.

### License
MIT — see `LICENSE`.
