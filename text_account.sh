#!/bin/bash

# text_account.sh
ACCOUNTS_FILE="accounts.json"
SALT="text_account_salt_2025"  # Fixed salt for SHA-256 hashing

# Initialize accounts.json if it doesn't exist
if [ ! -f "$ACCOUNTS_FILE" ]; then
    echo "{}" > "$ACCOUNTS_FILE"
fi

# Check dependencies
command -v jq >/dev/null 2>&1 || { echo "jq is required. Install with 'brew install jq'."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is required. Ensure macOS is updated."; exit 1; }

# Hash password using openssl SHA-256 with salt
hash_password() {
    local password="$1"
    echo -n "$password$SALT" | openssl dgst -sha256 | awk '{print $2}'
}

# Verify password
verify_password() {
    local password="$1"
    local stored_hash="$2"
    local computed_hash
    computed_hash=$(hash_password "$password")
    [ "$computed_hash" = "$stored_hash" ]
}

# Main menu
main_menu() {
    clear
    echo "Text Account App"
    echo "1. Register"
    echo "2. Login"
    echo "3. Quit"
    read -p "Choose an option (1-3): " choice
    case $choice in
        1) register ;;
        2) login ;;
        3) exit 0 ;;
        *) echo "Invalid option"; sleep 1; main_menu ;;
    esac
}

# Register a new user
register() {
    clear
    echo "Register"
    read -p "Enter username: " username
    if [ -z "$username" ]; then
        echo "Username cannot be empty"
        sleep 1
        main_menu
        return
    fi
    # Check if username exists
    if jq -e ".\"$username\"" "$ACCOUNTS_FILE" >/dev/null; then
        echo "Username already exists"
        sleep 1
        main_menu
        return
    fi
    while true; do
        read -s -p "Enter password (cannot be blank): " password
        echo
        if [ -z "$password" ]; then
            echo "Password cannot be blank"
        else
            break
        fi
    done
    hashed_password=$(hash_password "$password")
    # Add user to accounts.json
    jq ". + {\"$username\": {\"password\": \"$hashed_password\", \"text\": \"\"}}" "$ACCOUNTS_FILE" > tmp.json && mv tmp.json "$ACCOUNTS_FILE"
    echo "Account created"
    sleep 1
    main_menu
}

# Login and handle view/edit
login() {
    clear
    echo "Login"
    read -p "Enter username: " username
    if ! jq -e ".\"$username\"" "$ACCOUNTS_FILE" >/dev/null; then
        echo "Username does not exist"
        sleep 1
        main_menu
        return
    fi
    read -s -p "Enter password (blank to view): " password
    echo
    stored_password=$(jq -r ".\"$username\".password" "$ACCOUNTS_FILE")
    if [ -z "$password" ]; then
        # Blank password: view only
        view_text "$username"
    else
        # Verify password
        if verify_password "$password" "$stored_password"; then
            edit_text "$username"
        else
            echo "Incorrect password"
            sleep 1
            main_menu
        fi
    fi
}

# View text (read-only)
view_text() {
    local username="$1"
    clear
    echo "Viewing text for $username"
    text=$(jq -r ".\"$username\".text" "$ACCOUNTS_FILE")
    if [ -z "$text" ]; then
        echo "(empty)"
    else
        echo "$text"
    fi
    read -p "Press Enter to return..."
    main_menu
}

# Edit text
edit_text() {
    local username="$1"
    clear
    echo "Editing text for $username"
    echo "Current text:"
    text=$(jq -r ".\"$username\".text" "$ACCOUNTS_FILE")
    if [ -z "$text" ]; then
        echo "(empty)"
    else
        echo "$text"
    fi
    echo "Enter new text (press Ctrl+D when done):"
    new_text=$(cat)
    # Escape quotes in new_text for JSON
    new_text=$(echo "$new_text" | sed 's/"/\\"/g')
    # Update text in accounts.json
    jq ".\"$username\".text = \"$new_text\"" "$ACCOUNTS_FILE" > tmp.json && mv tmp.json "$ACCOUNTS_FILE"
    echo "Text saved"
    sleep 1
    main_menu
}

# Start the app
main_menu
