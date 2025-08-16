#!/bin/bash
set -euo pipefail
printf "============\n"
# Nextcloud directory as variable (adjust this to your Nextcloud installation path)
NEXTCLOUD_DIR="/var/www/nextcloud"

# Change to Nextcloud directory or exit if not found
cd "$NEXTCLOUD_DIR" || { echo "Error: Directory $NEXTCLOUD_DIR does not exist."; exit 1; }

# Define colors with printf-friendly escape sequences
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
RESET="\e[0m"

# Load database configuration from config.php (portable with sed)
DB_USER=$(sed -n "s/.*'dbuser' => '\([^']*\)'.*/\1/p" config/config.php)
DB_NAME=$(sed -n "s/.*'dbname' => '\([^']*\)'.*/\1/p" config/config.php)
DB_PASS=$(sed -n "s/.*'dbpassword' => '\([^']*\)'.*/\1/p" config/config.php)

# Unset sensitive variables at script exit
trap "unset DB_USER DB_NAME DB_PASS NC_ADMIN_USER" EXIT
# Ask for Nextcloud admin user with default 'admin'
read -rp "Please enter the Nextcloud admin user (default: admin): " NC_ADMIN_USER
NC_ADMIN_USER=${NC_ADMIN_USER:-admin}

printf "The administrator '%s' will be excluded from changes.\n\n" "$NC_ADMIN_USER"

printf "${BLUE}============${RESET}\n"
printf "${BOLD}   NEXTCLOUD MAINTENANCE${RESET}\n"
printf "${BLUE}============${RESET}\n"
printf " ${GREEN}INFO${RESET} %-12s = %s\n" "Nextcloud DIR" "$NEXTCLOUD_DIR"
printf " ${GREEN}INFO${RESET} %-12s = %s\n" "DB Name"       "$DB_NAME"
printf " ${GREEN}INFO${RESET} %-12s = %s\n" "DB User"       "$DB_USER"
printf "${BLUE}============${RESET}\n"
printf "${RED}   If you disable all users, remember which users were already disabled.\n"
printf "   Note that with this script, you can only enable all users at once later on.\n"
printf "   In Nextcloud, you can disable individual users again.${RESET}\n"

# Function to safely run MySQL command and exit on failure
mysql_exec() {
    if ! mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1"; then
        echo "Error: Database command failed." >&2
        exit 1
    fi
}

# Infinite loop for menu selection
while true; do
    printf "${BLUE}========================================${RESET}\n"
    printf "%bPlease choose an option:%b\n" "$BOLD" "$RESET"
    echo "1. Show users"
    echo "2. Disable all users except '$NC_ADMIN_USER'"
    echo "3. Enable all users"
    echo "4. Maintenance Mode ON"
    echo "5. Maintenance Mode OFF"
    echo "U. Nextcloud Update (create snapshot or backup first)"
    echo "D. Convert database tables to dynamic row format"
    echo "   (only if Nextcloud version 31 or later requires this)"
    printf "${GREEN}${BOLD}E. Exit${RESET}\n"
    printf "${BLUE}========================================${RESET}\n"

    read -rp "Input: " choice

    case $choice in
        1)
            echo "User list:"
            mysql_exec "
                SELECT u.uid, u.displayname,
                    COALESCE(p.configvalue, 'unknown') AS enabled
                FROM oc_users u
                LEFT JOIN oc_preferences p
                ON u.uid = p.userid AND p.configkey = 'enabled' AND p.appid = 'core';"
            ;;

        2)
            echo "Disabling all users except '$NC_ADMIN_USER'..."

            # Insert missing 'enabled' preference with 'false' for all except admin in one batch
            mysql_exec "
                INSERT INTO oc_preferences (userid, appid, configkey, configvalue)
                SELECT uid, 'core', 'enabled', 'false'
                FROM oc_users
                WHERE uid != '$NC_ADMIN_USER'
                  AND NOT EXISTS (
                    SELECT 1 FROM oc_preferences
                    WHERE userid = oc_users.uid AND configkey = 'enabled' AND appid = 'core'
                  );"

            # Update all existing entries to false except admin
            mysql_exec "
                UPDATE oc_preferences
                SET configvalue = 'false'
                WHERE configkey = 'enabled' AND appid = 'core' AND userid != '$NC_ADMIN_USER';"

            echo "All users except '$NC_ADMIN_USER' have been disabled."
            ;;

        3)
            echo "Enabling all users..."

            # Insert missing 'enabled' preference with 'true' for all users in one batch
            mysql_exec "
                INSERT INTO oc_preferences (userid, appid, configkey, configvalue)
                SELECT uid, 'core', 'enabled', 'true'
                FROM oc_users
                WHERE NOT EXISTS (
                    SELECT 1 FROM oc_preferences
                    WHERE userid = oc_users.uid AND configkey = 'enabled' AND appid = 'core'
                );"

            # Update all existing entries to true
            mysql_exec "
                UPDATE oc_preferences
                SET configvalue = 'true'
                WHERE configkey = 'enabled' AND appid = 'core';"

            echo "All users have been enabled."
            ;;

        4)
            echo "Maintenance Mode ON."
            sudo -u www-data php occ maintenance:mode --on
            systemctl restart apache2
            ;;

        5)
            echo "Maintenance Mode OFF."
            sudo -u www-data php occ maintenance:mode --off
            systemctl restart apache2
            ;;

        [Uu])
            read -rp "Was a VM snapshot created? (y/n) " snapshot_confirm
            if [[ "$snapshot_confirm" != [Yy] ]]; then
                echo "Please create a snapshot first. Aborting."
                exit 1
            fi

            read -rp "Was 'apt-get update' executed? (y/n) " apt_update_confirm
            if [[ "$apt_update_confirm" != [Yy] ]]; then
                echo "Please run 'apt-get update' first. Aborting."
                exit 1
            fi

            echo "Starting NextCloud update."
            sudo -u www-data php updater/updater.phar
            echo "NextCloud: occ db:add-missing-indices"
            sudo -u www-data php occ db:add-missing-indices
            echo "NextCloud: occ maintenance:repair --include-expensive"
            sudo -u www-data php occ maintenance:repair --include-expensive
            echo "Restarting Apache"
            sudo systemctl restart apache2
            echo "Done"
            ;;

        [Dd])
            read -rp "Was a VM snapshot or full backup created? (y/n) " snapshot_confirm
            if [[ "$snapshot_confirm" != [Yy] ]]; then
                echo "Please create a current backup or VM snapshot first. Aborting."
                exit 1
            fi

            echo "Changing all InnoDB tables to ROW_FORMAT=DYNAMIC (only if not already set)..."
            # Generate and execute ALTER TABLE statements in one batch
            mysql -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -Nse "
                SELECT CONCAT('ALTER TABLE \`', table_name, '\` ROW_FORMAT=DYNAMIC;')
                FROM information_schema.tables
                WHERE table_schema = '$DB_NAME' AND ENGINE = 'InnoDB' AND UPPER(ROW_FORMAT) != 'DYNAMIC';
            " | mysql -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME"

            echo "Done. Please check if Nextcloud still works correctly."
            ;;

        [Ee])
            echo "Program exited."
            exit 0
            ;;

        *)
            echo "Invalid choice, please try again."
            ;;
    esac
done
