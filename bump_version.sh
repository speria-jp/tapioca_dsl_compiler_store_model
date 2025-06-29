#!/bin/bash

# Script to bump gem version
# Usage examples: 
#   ./bump_version.sh patch
#   ./bump_version.sh minor  
#   ./bump_version.sh major
#   ./bump_version.sh 1.2.3

set -e

BUMP_TYPE="$1"

if [ -z "$BUMP_TYPE" ]; then
    echo "Usage: $0 <patch|minor|major|x.y.z>"
    echo "Examples:"
    echo "  $0 patch   # 1.0.0 -> 1.0.1"
    echo "  $0 minor   # 1.0.1 -> 1.1.0"
    echo "  $0 major   # 1.1.0 -> 2.0.0"
    echo "  $0 1.2.3   # Set specific version"
    exit 1
fi

# Get current version
get_current_version() {
    # Try to find version.rb in common locations
    for version_file in lib/version.rb lib/*/version.rb; do
        if [ -f "$version_file" ]; then
            grep -o "VERSION = ['\"][^'\"]*['\"]" "$version_file" | cut -d"'" -f2 | cut -d'"' -f2
            return
        fi
    done
    echo "0.0.0"
}

# Bump version
bump_version() {
    local current="$1"
    local type="$2"
    
    IFS='.' read -ra VERSION_PARTS <<< "$current"
    local major="${VERSION_PARTS[0]}"
    local minor="${VERSION_PARTS[1]}"
    local patch="${VERSION_PARTS[2]}"
    
    case "$type" in
        "patch")
            patch=$((patch + 1))
            ;;
        "minor") 
            minor=$((minor + 1))
            patch=0
            ;;
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        *)
            # Specific version is provided
            echo "$type"
            return
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

# Update files
update_files() {
    local new_version="$1"
    
    # Update version.rb
    if [ -f "lib/version.rb" ]; then
        sed -i.bak "s/VERSION = ['\"][^'\"]*['\"]/VERSION = \"${new_version}\"/" lib/version.rb
        rm lib/version.rb.bak
    fi
    
    # Update lib/gem_name/version.rb
    for version_file in lib/*/version.rb; do
        if [ -f "$version_file" ]; then
            sed -i.bak "s/VERSION = ['\"][^'\"]*['\"]/VERSION = \"${new_version}\"/" "$version_file"
            rm "${version_file}.bak"
        fi
    done
}

# Main process
CURRENT_VERSION=$(get_current_version)
echo "Current version: $CURRENT_VERSION"

NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP_TYPE")
echo "New version: $NEW_VERSION"

# Confirmation
read -p "Update version to $NEW_VERSION? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    update_files "$NEW_VERSION"
    echo "Version updated to $NEW_VERSION"
    
    # Update Gemfile.lock if gem references itself
    if grep -q "remote: \." Gemfile.lock 2>/dev/null; then
        echo "Updating Gemfile.lock..."
        bundle update tapioca_dsl_compiler_store_model
    fi
    
    echo "Don't forget to:"
    echo "  1. git add -A"
    echo "  2. git commit -m 'Bump version to $NEW_VERSION'"
    echo "  3. git tag v$NEW_VERSION"
    echo "  4. git push origin main --tags"
else
    echo "Version update cancelled"
fi