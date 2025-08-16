#!/bin/bash
# Nextcloud directory as variable
NEXTCLOUD_DIR="/var/www/nextcloud"

# Change to Nextcloud directory
cd "$NEXTCLOUD_DIR" || { echo "Error: Directory $NEXTCLOUD_DIR does not exist."; exit 1; }

# Define colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
RESET="\e[0m"

# Load database configuration from config.php
DB_USER=$(grep -oP "'dbuser' => '\K[^']+" config/config.php)
DB_NAME=$(grep -oP "'dbname' => '\K[^']+" config/config.php)
DB_PASS=$(grep -oP "'dbpassword' => '\K[^']+" config/config.php)

# Unset variables at script exit
trap "unset DB_USER DB_NAME DB_PASS NC_ADMIN_USER" EXIT

# Ask for Nextcloud admin user
read -p "Please enter the name of one of your Nextcloud admin users (default: admin): " NC_ADMIN_USER
NC_ADMIN_USER=${NC_ADMIN_USER:-admin} # Default value "admin" if nothing is entered
echo "The administrator '$NC_ADMIN_USER' will be excluded from changes in menu option: 2."

echo ""
echo -e "${BLUE}============================================================${RESET}"
echo -e "${BOLD}   NEXTCLOUD MAINTENANCE${RESET}"
echo -e "${BLUE}============================================================${RESET}"
echo -e " ${GREEN}INFO:${RESET} Nextcloud DIR:  ${NEXTCLOUD_DIR}"
echo -e " ${GREEN}INFO:${RESET} DB:             ${DB_NAME}"
echo -e " ${GREEN}INFO:${RESET} DB-User:        ${DB_USER}"
echo -e "${BLUE}============================================================${RESET}"
echo -e "${RED}   If you disable all users, remember which users were already disabled."
echo -e "${RED}   Later, you can only enable all users at once."
echo -e "${RED}   In Nextcloud, you can disable individual users later again.${RESET}"
echo -e "${BLUE}============================================================${RESET}"

# Infinite loop for menu selection
while true; do
    # Display menu options
	echo -e "${BLUE}============================================================${RESET}"
    echo -e "${BOLD}Please choose an option:"
    echo "1. Show users"
    echo "2. Disable all users except '$NC_ADMIN_USER'"
    echo "3. Enable all users"
    echo "4. Maintenance Mode ON"
    echo "5. Maintenance Mode OFF"
    echo "U. Nextcloud Update (create snapshot or backup first)"
    echo "D. Convert database tables to dynamic row format"
    echo "    (only if Nextcloud version 31 or later requires this)"
    echo -e "${RESET}${GREEN}${BOLD}E. Exit${RESET}"
    echo -e "${BLUE}============================================================${RESET}"
    # Get user input
    read -p "Input: " choice

    # Evaluate selection
    case $choice in
        1)
            # Show user list
			echo -e "${BLUE}============================================================${RESET}"
            echo "User list:"
            mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                SELECT u.uid, u.displayname,
                    COALESCE(p.configvalue, 'unknown') AS enabled
                FROM oc_users u
                LEFT JOIN oc_preferences p
                ON u.uid = p.userid AND p.configkey = 'enabled' AND p.appid = 'core';" -t
			
            ;;

        2)
            # Disable all users except admin
			echo -e "${BLUE}============================================================${RESET}"
            echo "Disabling all users except '$NC_ADMIN_USER'..."
            # First check if the 'enabled' entry with 'appid = core' exists, if not, insert it
            mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                SELECT uid FROM oc_users WHERE uid != '$NC_ADMIN_USER' AND NOT EXISTS (
                    SELECT 1 FROM oc_preferences
                    WHERE userid = oc_users.uid AND configkey = 'enabled' AND appid = 'core'
                )" | while read -r user; do
                    # If the entry does not exist, perform insert
                    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                        INSERT INTO oc_preferences (userid, appid, configkey, configvalue)
                        VALUES ('$user', 'core', 'enabled', 'false');"
                done

            # Then set all 'enabled' values to 'false' if they already exist
            mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                UPDATE oc_preferences
                SET configvalue = 'false'
                WHERE configkey = 'enabled' AND appid = 'core' AND userid != '$NC_ADMIN_USER';"
            echo "All users except '$NC_ADMIN_USER' have been disabled."
            ;;

        3)
            # Enable all users
			echo -e "${BLUE}============================================================${RESET}"
            echo "Enabling all users..."
            # First check if the 'enabled' entry with 'appid = core' exists, if not, insert it
            mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                SELECT uid FROM oc_users WHERE NOT EXISTS (
                    SELECT 1 FROM oc_preferences
                    WHERE userid = oc_users.uid AND configkey = 'enabled' AND appid = 'core'
                )" | while read -r user; do
                    # If the entry does not exist, perform insert
                    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                        INSERT INTO oc_preferences (userid, appid, configkey, configvalue)
                        VALUES ('$user', 'core', 'enabled', 'true');"
                done

            # Then set all 'enabled' values to 'true' if they already exist
            mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                UPDATE oc_preferences
                SET configvalue = 'true'
                WHERE configkey = 'enabled' AND appid = 'core';"
            echo "All users have been enabled."
            ;;

        4)
            # Maintenance Mode ON
			echo -e "${BLUE}============================================================${RESET}"
            echo "Maintenance Mode ON."
            sudo -u www-data php occ maintenance:mode --on
            systemctl restart apache2
            ;;

        5)
            # Maintenance Mode OFF
			echo -e "${BLUE}============================================================${RESET}"
            echo "Maintenance Mode OFF."
            sudo -u www-data php occ maintenance:mode --off
            systemctl restart apache2
            ;;

        U)
            # Ask if snapshot was created
			echo -e "${BLUE}============================================================${RESET}"
            read -p "Was a VM snapshot created? (y/n) " snapshot_confirm
            if [[ "$snapshot_confirm" != "y" && "$snapshot_confirm" != "Y" ]]; then
                echo "Please create a snapshot first. Aborting."
                exit 1
            fi

            # Ask if apt-get update was run
            read -p "Was 'apt-get update' executed? (y/n) " apt_update_confirm
            if [[ "$apt_update_confirm" != "y" && "$apt_update_confirm" != "Y" ]]; then
                echo "Please run 'apt-get update' first. Aborting."
                exit 1
            fi
            echo -e "${BLUE}============================================================${RESET}" 
            echo "Starting NextCloud update."
            sudo -u www-data php updater/updater.phar
			echo -e "${BLUE}============================================================${RESET}"
            echo "NextCloud: occ db:add-missing-indices"
            sudo -u www-data php occ db:add-missing-indices
			echo -e "${BLUE}============================================================${RESET}"
            echo "NextCloud: occ maintenance:repair --include-expensive"
            sudo -u www-data php occ maintenance:repair --include-expensive
			echo -e "${BLUE}============================================================${RESET}"
            echo "Restarting Apache"
            sudo systemctl restart apache2
            echo "Done"
            ;;

        D)
            # Safety check before database changes
			echo -e "${BLUE}============================================================${RESET}"
            read -p "Was a VM snapshot or full backup created? (y/n) " snapshot_confirm
            if [[ "$snapshot_confirm" != "y" && "$snapshot_confirm" != "Y" ]]; then
                echo "Please create a current backup or VM snapshot first. Aborting."
                exit 1
            fi
            echo -e "${BLUE}============================================================${RESET}"
            echo "Changing all InnoDB tables to ROW_FORMAT=DYNAMIC (only if not already set)..."

            mysql -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -Nse "
            SELECT CONCAT('ALTER TABLE \`', table_name, '\` ROW_FORMAT=DYNAMIC;')
            FROM information_schema.tables
            WHERE table_schema = '$DB_NAME'
              AND ENGINE = 'InnoDB'
              AND UPPER(ROW_FORMAT) != 'DYNAMIC';
            " | mysql -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME"
            echo -e "${BLUE}============================================================${RESET}"
            echo "Done. Please check if Nextcloud still works correctly."
            ;;

        E)
            # Exit program
            echo "Program exited."
            exit 0
            ;;

        *)
            # Handle invalid input
            echo "Invalid choice, please try again."
            ;;
    esac
done
