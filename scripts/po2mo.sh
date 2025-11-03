#!/bin/bash
# Convert PO files to MO files for all locales
# This script requires gettext tools (msgfmt) to be installed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Determine plugin directory based on where script is run from
if [ -d "readingstreak.koplugin" ]; then
    # Running from parent directory
    PLUGIN_DIR="readingstreak.koplugin"
elif [ -f "_meta.lua" ]; then
    # Running from plugin directory itself
    PLUGIN_DIR="."
else
    # Default: assume script is in plugin/scripts/
    PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
fi
L10N_DIR="$PLUGIN_DIR/l10n"

if [ ! -d "$L10N_DIR" ]; then
    echo "Error: l10n directory not found at $L10N_DIR"
    exit 1
fi

# Check if msgfmt is available
if ! command -v msgfmt &> /dev/null; then
    echo "Error: msgfmt command not found. Please install gettext tools."
    echo "On Ubuntu/Debian: sudo apt-get install gettext"
    echo "On macOS: brew install gettext"
    exit 1
fi

# Convert all PO files to MO files
for lang_dir in "$L10N_DIR"/*; do
    if [ -d "$lang_dir" ]; then
        po_file="$lang_dir/readingstreak.po"
        mo_file="$lang_dir/readingstreak.mo"
        
        if [ -f "$po_file" ]; then
            echo "Converting $po_file to $mo_file..."
            msgfmt -o "$mo_file" "$po_file"
            if [ $? -eq 0 ]; then
                echo "✓ Successfully converted $(basename "$lang_dir")/readingstreak.po"
            else
                echo "✗ Failed to convert $(basename "$lang_dir")/readingstreak.po"
                exit 1
            fi
        fi
    fi
done

echo "All PO files converted successfully!"

