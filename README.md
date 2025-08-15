# Nextcloud Maintenance Script

**A Bash script for Nextcloud administrators to safely disable all users (except admin) before updates, toggle maintenance mode, and perform essential maintenance tasks.**

---

## Features

- **User Management:** List, disable, and enable all users except admin to prevent data changes during maintenance.
- **Maintenance Mode:** Easily toggle Nextcloud maintenance mode on or off.
- **Safe Nextcloud Updates:** Update Nextcloud with backup confirmation.
- **Database Optimization:** Convert InnoDB tables to dynamic row format, required for Nextcloud 31+.
- **Automatic Configuration:** Reads database credentials directly from `config.php`, no manual input necessary.

---

## Requirements

- Nextcloud installation (tested on Debian Buster/Bullseye/Bookworm with Apache2, InnoDB, and PHP 8.0–8.3).  
  *Please report if used with other setups.*
- Apache2 with InnoDB support
- PHP 8.0, 8.1, 8.2, or 8.3
- Nextcloud versions 27 to 31
- MySQL or MariaDB
- Bash shell with sudo rights

---

## Usage

1. Save the script as `nextcloud-maintenance.sh` in the default Nextcloud directory `/var/www/nextcloud`.  
   *(Adjust the `NEXTCLOUD_DIR` variable if your installation path is different.)*
2. Make the script executable:  
   chmod +x nextcloud-maintenance.sh
3. Run the script with sudo:  
   sudo ./nextcloud-maintenance.sh
4. Follow the on-screen menu prompts.

---

## Important Notes

⚠️ **Warning:** This script comes with **no warranty**.  
The author is **not liable** for any damage or data loss.  
**Always create a backup or VM snapshot before use!**  

This script helps prevent user changes during updates (e.g., calendar entries, file uploads). After updating, test Nextcloud as admin and then re-enable all users using this script.

---

## Donations

If you find this script useful, feel free to support me via PayPal: allererst@googlemail.com

---

## Changelog

- **1.0.0** – Initial release

---

## License

GPLv3 – Copyright (C) 2025 Frank Meurer (@meurologic.de)
