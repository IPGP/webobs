#!/bin/bash

# Check if the target file or directory is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file_or_directory>"
    exit 1
fi

target="$1"

# Function to convert a file from any ISO-8859 variant to UTF-8
convert_file() {
    local file="$1"
    local enc
    enc=$(file -b --mime-encoding "$file" 2>/dev/null)

    # Check if 'file' command succeeded
    if [[ "$?" -ne 0 || -z "$enc" ]]; then
        echo "Error: Could not determine encoding for $file" >&2
        return 1
    fi

    # Check for any ISO-8859 variant
    if [[ "$enc" == *"iso-8859"* ]]; then
        echo "Backing up and converting $file ($enc → UTF-8)..."

        # Backup the original file
        if ! cp "$file" "$file.bak"; then
            echo "Error: Failed to backup $file" >&2
            return 1
        fi

        # Convert encoding (using the detected ISO-8859 variant)
        if ! iconv -f "$enc" -t UTF-8 "$file.bak" -o "$file"; then
            echo "Error: Conversion failed for $file" >&2
            # Restore the original file on failure
            if ! mv "$file.bak" "$file"; then
                echo "Error: Failed to restore $file from backup" >&2
            fi
            return 1
        fi

        echo "Success: $file converted to UTF-8"
    fi
}

# If target is a file
if [ -f "$target" ]; then
    convert_file "$target"
# If target is a directory
elif [ -d "$target" ]; then
    find "$target" -type f -exec file {} + 2>/dev/null | grep -E ':.*text' | cut -d: -f1 | while read -r file; do
        convert_file "$file" || echo "Skipping $file due to errors" >&2
    done
else
    echo "Error: '$target' is neither a file nor a directory." >&2
    exit 1
fi

echo "Conversion complete."

