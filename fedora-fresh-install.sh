#!/bin/bash

# Fedora Setup Script
# This script sets up a Fedora system with custom configurations

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/mmalaban/fedora-scripts.git"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Meslo.zip"
PACKAGES_FILE="packages.txt"
TMP_DIR="tmp"
BASHRC_DIR=".bashrc.d"
FASTFETCH_CONFIG_DIR=".config/fastfetch"
FASTFETCH_CONFIG_FILE="12.jsonc"
OH_MY_POSH_CONFIG_DIR=".config/oh-my-posh"
OH_MY_POSH_CONFIG_FILE="catppuccin_macchiato.omp.json"
FONT_DIR="$HOME/.local/share/fonts"

# Global dry-run flag
DRY_RUN=false

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_dry_run() {
    echo -e "${YELLOW}[DRY-RUN]${NC} $1"
}

# Check if script is running with sudo privileges
check_sudo_privileges() {
    log_info "Checking for sudo privileges..."
    
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root"
        log_error "Please run as a regular user with sudo access"
        exit 1
    elif sudo -n true 2>/dev/null; then
        log_success "User has passwordless sudo access"
        return 0
    else
        log_error "This script requires sudo privileges"
        log_error "Please ensure you have sudo access"
        exit 1
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would execute: sudo dnf update -y"
        log_success "System would be updated successfully"
        return 0
    fi
    
    if sudo dnf update -y; then
        log_success "System updated successfully"
    else
        log_error "Failed to update system"
        exit 1
    fi
}

# Validate packages file
validate_packages_file() {
    if [[ ! -f "$PACKAGES_FILE" ]]; then
        log_error "Package file '$PACKAGES_FILE' not found"
        exit 1
    fi
    
    if [[ ! -r "$PACKAGES_FILE" ]]; then
        log_error "Package file '$PACKAGES_FILE' is not readable"
        exit 1
    fi
}

# Parse packages from file
parse_packages_file() {
    local packages=$(grep -v '^\s*#' "$PACKAGES_FILE" | grep -v '^\s*$' | tr '\n' ' ')
    
    if [[ -z "$packages" ]]; then
        log_warning "No packages found in $PACKAGES_FILE"
        return 1
    fi
    
    # Validate package names (basic security check)
    local invalid_chars="[;&|<>(){}]"
    if [[ "$packages" =~ $invalid_chars ]]; then
        log_error "Invalid characters detected in package list - potential security risk"
        exit 1
    fi
    
    echo "$packages"
}

# Install packages from packages.txt file
install_packages() {
    log_info "Installing packages from $PACKAGES_FILE..."
    
    validate_packages_file
    
    local packages=$(parse_packages_file)
    if [[ $? -ne 0 ]]; then
        return 0
    fi
    
    log_info "Installing packages: $packages"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would execute: sudo dnf install -y $packages"
        log_success "Packages would be installed successfully"
        return 0
    fi
    
    if sudo dnf install -y $packages; then
        log_success "Packages installed successfully"
    else
        log_error "Failed to install packages"
        exit 1
    fi
}

# Create a single directory
create_directory() {
    local dir="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -d "$dir" ]]; then
            log_dry_run "Directory already exists: $dir"
        else
            log_dry_run "Would create directory: $dir"
        fi
        return 0
    fi
    
    if mkdir -p "$dir"; then
        log_success "Created directory: $dir"
    else
        log_error "Failed to create directory: $dir"
        exit 1
    fi
}

# Create all required directories
create_directories() {
    log_info "Creating required directories..."
    
    local dirs=("$TMP_DIR" "$BASHRC_DIR" "$FASTFETCH_CONFIG_DIR" "$OH_MY_POSH_CONFIG_DIR" "$FONT_DIR")
    
    for dir in "${dirs[@]}"; do
        create_directory "$dir"
    done
}

# Clone repository
clone_repository() {
    local repo_url="$1"
    local dest_dir="$2"
    
    log_info "Cloning repository: $repo_url"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -d "$dest_dir" ]]; then
            log_dry_run "Would remove existing repository clone: $dest_dir"
        fi
        log_dry_run "Would execute: git clone $repo_url $dest_dir"
        log_success "Repository would be cloned successfully"
        return 0
    fi
    
    # Remove existing clone if it exists
    if [[ -d "$dest_dir" ]]; then
        log_warning "Removing existing repository clone"
        rm -rf "$dest_dir"
    fi
    
    # Clone repository
    if git clone "$repo_url" "$dest_dir"; then
        log_success "Repository cloned successfully"
    else
        log_error "Failed to clone repository"
        exit 1
    fi
}

# Copy files from source to destination
copy_files() {
    local source_dir="$1"
    local dest_dir="$2"
    local description="$3"
    
    log_info "Copying $description from $source_dir to $dest_dir..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would copy files from $source_dir to $dest_dir"
        log_success "Files would be copied successfully"
        return 0
    fi
    
    # Copy only files (not directories) from source
    if find "$source_dir" -maxdepth 1 -type f -exec cp {} "$dest_dir/" \;; then
        log_success "Files copied successfully"
    else
        log_error "Failed to copy files"
        exit 1
    fi
}

# Clone fedora-scripts repository
clone_fedora_scripts() {
    clone_repository "$REPO_URL" "$TMP_DIR/fedora-scripts"
}

# Copy repository files to bashrc directory
copy_repo_files() {
    copy_files "$TMP_DIR/fedora-scripts" "$BASHRC_DIR" "repository files"
}

# Check if command exists
check_command() {
    local cmd="$1"
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd command not found. Please install $cmd package first."
        exit 1
    fi
}

# Validate directory exists
validate_directory() {
    local dir="$1"
    local description="$2"
    
    if [[ ! -d "$dir" ]]; then
        log_error "$description directory does not exist: $dir"
        exit 1
    fi
}

# Download file from URL
download_file() {
    local url="$1"
    local dest_file="$2"
    
    log_info "Downloading from: $url"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would download: $url to $dest_file"
        return 0
    fi
    
    if curl -L --max-time 300 --max-redirs 5 -o "$dest_file" "$url"; then
        log_success "File downloaded successfully"
    else
        log_error "Failed to download file"
        exit 1
    fi
}

# Validate downloaded file
validate_download() {
    local file="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
        log_error "Downloaded file is missing or empty: $file"
        exit 1
    fi
}

# Extract zip file
extract_zip() {
    local zip_file="$1"
    local extract_dir="$2"
    
    log_info "Extracting font files..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would extract $zip_file to $extract_dir"
        return 0
    fi
    
    mkdir -p "$extract_dir"
    
    if unzip -q "$zip_file" -d "$extract_dir"; then
        log_success "Files extracted successfully"
    else
        log_error "Failed to extract files - file may be corrupted"
        exit 1
    fi
}

# Install font files
install_font_files() {
    local source_dir="$1"
    local dest_dir="$2"
    
    log_info "Installing fonts to $dest_dir..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would install font files from $source_dir to $dest_dir"
        log_success "Font files would be installed successfully"
        return 0
    fi
    
    # Find and copy all font files (.ttf, .otf) - prevent directory traversal
    local font_count=0
    while IFS= read -r -d '' font_file; do
        # Security check: ensure file is actually a font file and within expected directory
        if [[ "$font_file" == "$source_dir"* ]] && [[ -f "$font_file" ]]; then
            local filename=$(basename "$font_file")
            # Additional security: validate filename doesn't contain dangerous characters
            if [[ "$filename" =~ ^[a-zA-Z0-9._-]+\.(ttf|otf)$ ]]; then
                if cp "$font_file" "$dest_dir/$filename"; then
                    ((font_count++))
                else
                    log_warning "Failed to copy font: $filename"
                fi
            else
                log_warning "Skipping file with invalid name: $filename"
            fi
        fi
    done < <(find "$source_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)
    
    if [[ $font_count -gt 0 ]]; then
        log_success "Installed $font_count font files"
    else
        log_error "No font files were installed"
        exit 1
    fi
}

# Update font cache
update_font_cache() {
    local font_dir="$1"
    
    log_info "Updating font cache..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would execute: fc-cache -fv $font_dir"
        return 0
    fi
    
    if fc-cache -fv "$font_dir" >/dev/null 2>&1; then
        log_success "Font cache updated"
    else
        log_warning "Failed to update font cache, fonts may not be immediately available"
    fi
}

# Download and install Meslo Nerd Font
download_and_install_font() {
    log_info "Downloading Meslo Nerd Font..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would check if unzip command is available"
        log_dry_run "Would download: $FONT_URL to $TMP_DIR/Meslo.zip"
        log_dry_run "Would extract font files to $TMP_DIR/meslo_fonts"
        log_dry_run "Would install font files to $FONT_DIR"
        log_dry_run "Would execute: fc-cache -fv $FONT_DIR"
        log_success "Font would be downloaded and installed successfully"
        return 0
    fi
    
    check_command "unzip"
    validate_directory "$TMP_DIR" "tmp"
    
    local font_zip="$TMP_DIR/Meslo.zip"
    local font_extract_dir="$TMP_DIR/meslo_fonts"
    
    download_file "$FONT_URL" "$font_zip"
    validate_download "$font_zip"
    extract_zip "$font_zip" "$font_extract_dir"
    validate_directory "$FONT_DIR" "Font"
    install_font_files "$font_extract_dir" "$FONT_DIR"
    update_font_cache "$FONT_DIR"
}

# Check if config file exists and prompt for overwrite
check_config_file() {
    local config_path="$1"
    local config_name="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -f "$config_path" ]]; then
            log_dry_run "Config file already exists: $config_path"
            log_dry_run "Would prompt to overwrite existing file"
        else
            log_dry_run "Would create $config_name config: $config_path"
        fi
        return 0
    fi
    
    # Check if configuration file already exists
    if [[ -f "$config_path" ]]; then
        log_warning "$config_name config file already exists: $config_path"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping $config_name configuration creation"
            return 1
        fi
    fi
    return 0
}

# Write fastfetch config content
write_fastfetch_config() {
    local config_path="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log_info "Writing fastfetch configuration to: $config_path"
    
    # Ensure directory exists
    local config_dir=$(dirname "$config_path")
    mkdir -p "$config_dir"
    
    # Write configuration with error checking
    if cat > "$config_path" << 'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "none"
    },
    "display": {
        "separator": "->   ",
        "color": {
            "separator": "1"
        }
    },
    "modules": [
        {
            "type": "title",
            "format": "                                {6}{7}{8}"
        },
        "break",
        {
            "type": "custom",
            "format": "┌───────────────────────────── {#1}System Information{#} ─────────────────────────────┐"
        },
        "break",
        {
            "key": "     OS           ",
            "keyColor": "red",
            "type": "os"
        },
        {
            "key": "    󰌢 Machine      ",
            "keyColor": "green",
            "type": "host"
        },
        {
            "key": "     Kernel       ",
            "keyColor": "magenta",
            "type": "kernel"
        },
        {
            "key": "    󰅐 Uptime       ",
            "keyColor": "red",
            "type": "uptime"
        },
        {
            "key": "     Packages     ",
            "keyColor": "cyan",
            "type": "packages"
        },
        {
            "key": "    󰍹 Resolution   ",
            "keyColor": "yellow",
            "type": "display",
            "compactType": "original-with-refresh-rate"
        },
        {
            "key": "     WM           ",
            "keyColor": "blue",
            "type": "wm"
        },
        {
            "key": "     DE           ",
            "keyColor": "green",
            "type": "de"
        },
        {
            "key": "     Shell        ",
            "keyColor": "cyan",
            "type": "shell"
        },
        {
            "key": "     Terminal     ",
            "keyColor": "red",
            "type": "terminal"
        },
        {
            "key": "    󰻠 CPU          ",
            "keyColor": "yellow",
            "type": "cpu"
        },
        {
            "key": "    󰍛 GPU          ",
            "keyColor": "blue",
            "type": "gpu"
        },
        {
            "key": "     Disk         ",
            "keyColor": "green",
            "type": "disk"
        },
        {
            "key": "    󰑭 Memory       ",
            "keyColor": "magenta",
            "type": "memory"
        },
        "break",
        {
            "type": "custom",
            "format": "└──────────────────────────────────────────────────────────────────────────────┘"
        },
        "break",
        {
            "type": "colors",
            "paddingLeft": 34,
            "symbol": "circle"
        }
    ]
}
EOF
    then
        return 0
    else
        log_error "Failed to write fastfetch configuration"
        return 1
    fi
}

# Create fastfetch configuration
create_fastfetch_config() {
    log_info "Creating fastfetch configuration..."
    
    local config_path="$FASTFETCH_CONFIG_DIR/$FASTFETCH_CONFIG_FILE"
    
    if ! check_config_file "$config_path" "fastfetch"; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Fastfetch configuration would be created successfully"
        return 0
    fi
    
    if write_fastfetch_config "$config_path"; then
        log_success "Fastfetch configuration created: $config_path"
    else
        log_error "Failed to create fastfetch configuration"
        exit 1
    fi
}

# Install Oh My Posh
install_oh_my_posh() {
    log_info "Installing Oh My Posh..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would execute: curl -s https://ohmyposh.dev/install.sh | bash -s"
        log_success "Oh My Posh would be installed successfully"
        return 0
    fi
    
    if curl -s https://ohmyposh.dev/install.sh | bash -s; then
        log_success "Oh My Posh installed successfully"
    else
        log_error "Failed to install Oh My Posh"
        exit 1
    fi
}

# Write Oh My Posh config content
write_oh_my_posh_config() {
    local config_path="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log_info "Writing Oh My Posh configuration to: $config_path"
    
    # Ensure directory exists
    local config_dir=$(dirname "$config_path")
    mkdir -p "$config_dir"
    
    # Write configuration with error checking
    if cat > "$config_path" << 'EOF'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "palette": {
        "os": "#ACB0BE",
        "closer": "p:os",
        "pink": "#F5BDE6",
        "lavender": "#B7BDF8",
        "blue":  "#8AADF4"
  },
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "segments": [
        {
          "foreground": "p:os",
          "style": "plain",
          "template": "{{.Icon}} ",
          "type": "os"
        },
        {
          "foreground": "p:blue",
          "style": "plain",
          "template": "{{ .UserName }}@{{ .HostName }} ",
          "type": "session"
        },
        {
          "foreground": "p:pink",
          "properties": {
            "folder_icon": "..\ue5fe..",
            "home_icon": "~",
            "style": "agnoster_short"
          },
          "style": "plain",
          "template": "{{ .Path }} ",
          "type": "path"
        },
        {
          "foreground": "p:lavender",
          "properties": {
            "branch_icon": "\ue725 ",
            "cherry_pick_icon": "\ue29b ",
            "commit_icon": "\uf417 ",
            "fetch_status": false,
            "fetch_upstream_icon": false,
            "merge_icon": "\ue727 ",
            "no_commits_icon": "\uf0c3 ",
            "rebase_icon": "\ue728 ",
            "revert_icon": "\uf0e2 ",
            "tag_icon": "\uf412 "
          },
          "template": "{{ .HEAD }} ",
          "style": "plain",
          "type": "git"
        },
        {
          "style": "plain",
          "foreground": "p:closer",
          "template": ":",
          "type": "text"
        }
      ]      
    },
    {
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "background": "p:error-background",
          "foreground": "p:backgrond-color",
          "style": "diamond",
          "leading_diamond": "\ue0c7",
          "trailing_diamond": "\ue0c6",
          "template": " \uf0e7 ",
          "type": "root"
        },
        {
          "background": "p:background-color",
          "foreground": "p:git-text",
          "style": "plain",
          "template": "{{ if .Root }}{{ else }}<p:symbol-color> $ </>{{ end }}",
          "type": "text"
        }
      ],
      "type": "prompt"
    }
  ],
  "final_space": true,
  "version": 3
}
EOF
    then
        return 0
    else
        log_error "Failed to write Oh My Posh configuration"
        return 1
    fi
}

# Create Oh My Posh configuration
create_oh_my_posh_config() {
    log_info "Creating Oh My Posh configuration..."
    
    local config_path="$OH_MY_POSH_CONFIG_DIR/$OH_MY_POSH_CONFIG_FILE"
    
    if ! check_config_file "$config_path" "Oh My Posh"; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Oh My Posh configuration would be created successfully"
        return 0
    fi
    
    if write_oh_my_posh_config "$config_path"; then
        log_success "Oh My Posh configuration created: $config_path"
    else
        log_error "Failed to create Oh My Posh configuration"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -d "$TMP_DIR" ]]; then
            log_dry_run "Would remove temporary directory: $TMP_DIR"
        fi
        log_success "Cleanup would be completed"
        return 0
    fi
    
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
        log_success "Cleanup completed"
    fi
}

# Display summary
display_summary() {
    echo
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry-run completed successfully!"
        echo
        echo "Summary of actions that WOULD be performed:"
        echo "  ✓ System would be updated"
        echo "  ✓ Packages would be installed from $PACKAGES_FILE"
        echo "  ✓ Directories would be created: $TMP_DIR, $BASHRC_DIR, $FASTFETCH_CONFIG_DIR, $OH_MY_POSH_CONFIG_DIR, $FONT_DIR"
        echo "  ✓ Repository would be cloned and files copied to $BASHRC_DIR"
        echo "  ✓ Meslo Nerd Font would be downloaded and installed"
        echo "  ✓ Fastfetch configuration would be created"
        echo "  ✓ Oh My Posh would be installed and configured"
        echo "  ✓ Temporary files would be cleaned up"
        echo
        log_info "To actually execute these changes, run the script without --dry-run"
    else
        log_success "Setup completed successfully!"
        echo
        echo "Summary of actions performed:"
        echo "  ✓ System updated"
        echo "  ✓ Packages installed from $PACKAGES_FILE"
        echo "  ✓ Directories created: $TMP_DIR, $BASHRC_DIR, $FASTFETCH_CONFIG_DIR, $OH_MY_POSH_CONFIG_DIR, $FONT_DIR"
        echo "  ✓ Repository cloned and files copied to $BASHRC_DIR"
        echo "  ✓ Meslo Nerd Font downloaded and installed"
        echo "  ✓ Fastfetch configuration created"
        echo "  ✓ Oh My Posh installed and configured"
        echo "  ✓ Temporary files cleaned up"
        echo
        log_info "Please restart your terminal or source your shell configuration to apply changes."
    fi
}

# Main execution function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run    Show what would be done without executing"
                echo "  -h, --help   Display this help message"
                echo ""
                echo "Description:"
                echo "  This script sets up a Fedora system with custom configurations."
                echo "  It installs packages, downloads fonts, and configures fastfetch and Oh My Posh."
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Starting Fedora setup script in DRY-RUN mode..."
        log_info "No actual changes will be made to your system"
    else
        log_info "Starting Fedora setup script..."
    fi
    
    # Execute setup steps
    check_sudo_privileges
    update_system
    install_packages
    create_directories
    clone_fedora_scripts
    copy_repo_files
    download_and_install_font
    create_fastfetch_config
    install_oh_my_posh
    create_oh_my_posh_config
    cleanup
    display_summary
}

# Trap to cleanup on script exit
trap cleanup EXIT

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi