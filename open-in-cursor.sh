#!/bin/bash

# Script to open the currently active Xcode file in Cursor at the same cursor position
# Usage: Configure as an Xcode Behavior with a keyboard shortcut

# Enable debugging - output will go to both terminal and Console.app
exec > >(tee >(logger -t "open-in-cursor")) 2>&1
echo "Script started at $(date)"
echo "PATH: $PATH"
echo "USER: $USER"
echo "PWD: $PWD"

# Xcode behaviors have limited PATH - add common Cursor locations
# This is needed because Xcode behaviors don't inherit the full shell PATH
export PATH="/usr/local/bin:/opt/homebrew/bin:/Applications/Cursor.app/Contents/Resources/app/bin:$PATH"

# Check if Cursor is installed
echo "Checking for cursor command..."
if ! command -v cursor &> /dev/null; then
    echo "Error: Cursor command line tools not found. Install Cursor and add 'cursor' to your PATH."
    echo "Current PATH: $PATH"
    exit 1
fi

echo "Found cursor at: $(which cursor)"

# Get file path using AppleScript (get the last source document which is usually the active one)
echo "Getting file path from Xcode..."
file_path=$(osascript -e "
tell application \"Xcode\"
    try
        -- Get the filename from the current window title
        set last_word_in_main_window to (word -1 of (get name of window 1))
        
        if (last_word_in_main_window is \"Edited\") then
            error \"Please save the current document before running this script\"
        else
            -- Find the document whose name ends with the filename from window title
            set current_document to document 1 whose name ends with last_word_in_main_window
            set current_document_path to path of current_document
            return current_document_path
        end if
        
    on error errMsg
        if errMsg contains \"Can't get document\" then
            error \"No matching document found - ensure file is open in Xcode\"
        else if errMsg contains \"Can't get window\" then
            error \"No Xcode window found - ensure Xcode is active\"
        else
            error errMsg
        end if
    end try
end tell
" 2>/dev/null)

echo "File path result: '$file_path'"

# Get line and column number using AppleScript
echo "Getting caret position from Xcode..."
caret_position=$(osascript -e "
tell application \"Xcode\"
    try
        -- Get the filename from the current window title  
        set last_word_in_main_window to (word -1 of (get name of window 1))
        
        if (last_word_in_main_window is \"Edited\") then
            error \"Please save the current document before running this script\"
        else
            -- Find the same document and get caret position
            set current_document to document 1 whose name ends with last_word_in_main_window
            
            -- Get the selected character range directly (loc is 0-based)
            set {loc, len} to selected character range of current_document
            set fullText to the text of current_document
            
            -- Handle start-of-file
            if loc = 0 then
                return \"1:1\"
            else
                -- AppleScript text is 1-based; take the prefix up to loc characters
                set prefix to text 1 thru loc of fullText
                
                -- Check if caret is at end of line (prefix ends with newline)
                if prefix ends with return or prefix ends with linefeed then
                    -- Caret is at end of line, remove the newline for calculation
                    set prefixWithoutNewline to text 1 thru -2 of prefix
                    set lineNum to (count paragraphs of prefixWithoutNewline)
                    set lastPara to paragraph -1 of prefixWithoutNewline
                    set colNum to (length of lastPara) + 1
                else
                    -- Normal case: caret is in middle of line
                    set lineNum to (count paragraphs of prefix)
                    set lastPara to paragraph -1 of prefix
                    set colNum to (length of lastPara)
                end if
                
                return (lineNum as string) & \":\" & (colNum as string)
            end if
        end if
        
    on error errMsg
        if errMsg contains \"Can't get document\" then
            return \"1:1\"
        else if errMsg contains \"Can't get window\" then
            return \"1:1\"
        else
            return \"1:1\"
        end if
    end try
end tell
" 2>/dev/null)

# Parse line and column from the result  
line_number=$(echo "$caret_position" | cut -d: -f1)
column_number=$(echo "$caret_position" | cut -d: -f2)

echo "Caret position result: line $line_number, column $column_number"

# Check if we got valid data
if [ -z "$file_path" ] || [ -z "$line_number" ] || [ -z "$column_number" ]; then
    echo "Error: Could not get current file information from Xcode"
    echo "File path: '$file_path'"
    echo "Line: '$line_number'"
    echo "Column: '$column_number'"
    exit 1
fi

echo "Successfully got file info: $file_path at line $line_number, column $column_number"

# Check if file exists
if [ ! -f "$file_path" ]; then
    echo "Error: File does not exist: $file_path"
    exit 1
fi

# Find the project root directory
project_root=""
current_dir=$(dirname "$file_path")

# Look for .xcodeproj or .xcworkspace going up the directory tree
while [ "$current_dir" != "/" ]; do
    if [ -n "$(find "$current_dir" -maxdepth 1 -name "*.xcodeproj" -o -name "*.xcworkspace" 2>/dev/null)" ]; then
        project_root="$current_dir"
        break
    fi
    current_dir=$(dirname "$current_dir")
done

# If no project root found, use the file's directory
if [ -z "$project_root" ]; then
    project_root=$(dirname "$file_path")
    echo "Warning: No Xcode project found in parent directories, using file directory: $project_root"
else
    echo "Found project root: $project_root"
fi

echo "Opening project in Cursor and navigating to $file_path at line $line_number, column $column_number..."

# Open the project directory in Cursor, then navigate to the specific file, line, and column
echo "Running: cursor '$project_root' --goto '$file_path:$line_number:$column_number'"

cursor "$project_root" --goto "$file_path:$line_number:$column_number"

echo "Done! Script completed successfully."
