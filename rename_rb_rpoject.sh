#!/bin/bash

# Store the old and new names
OLD_NAME="secret_ovanta"
NEW_NAME="tecret_anta"
OLD_CLASS="SecretOvanta"
NEW_CLASS="TecretAnta"

# Function to check if command succeeded
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

echo "Starting project rename from $OLD_NAME to $NEW_NAME..."

# Rename directories
mv "lib/$OLD_NAME" "lib/$NEW_NAME" 2>/dev/null
check_status "Failed to rename lib directory"

# Rename main lib file
mv "lib/$OLD_NAME.rb" "lib/$NEW_NAME.rb" 2>/dev/null
check_status "Failed to rename main lib file"

# Rename gemspec file
mv "$OLD_NAME.gemspec" "$NEW_NAME.gemspec" 2>/dev/null
check_status "Failed to rename gemspec file"

# Update content in files
find . -type f -exec sed -i "s/$OLD_NAME/$NEW_NAME/g" {} +
find . -type f -exec sed -i "s/$OLD_CLASS/$NEW_CLASS/g" {} +

# Update specific files
files=(
    "lib/$NEW_NAME.rb"
    "lib/$NEW_NAME/version.rb"
    "$NEW_NAME.gemspec"
    "Gemfile"
    "bin/console"
    "README.md"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "Updating $file..."
        sed -i "s/$OLD_NAME/$NEW_NAME/g" "$file"
        sed -i "s/$OLD_CLASS/$NEW_CLASS/g" "$file"
    fi
done

echo "Project renamed successfully!"
echo "Please review the changes and update any remaining references manually if needed."
echo "Don't forget to:"
echo "1. Update your git remote if needed"
echo "2. Review and test the code"
echo "3. Commit the changes"