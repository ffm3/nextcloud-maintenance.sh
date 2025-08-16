# Nextcloud Maintenance Script

**A Bash script for Nextcloud administrators to safely disable all users (except admin) before updates, toggle maintenance mode, and perform essential maintenance tasks.**

---

## Benefits / Why use this script?

One of the greatest advantages of this script is the power and peace of mind it brings to Nextcloud administrators during updates. Imagine: before you update, with just a few commands, you can switch Nextcloud into maintenance mode and temporarily deactivate all users except the admin account you specify at the start.

Why is this so important? After an update, you may not immediately know if everything is working perfectly. Normally, if you disable maintenance mode too soon, users could start making changes—uploading files, modifying calendars, and updating data. But what if you discover a problem and need to restore a backup? Any changes made in the meantime could be lost, potentially causing data conflicts or even frustration among your users.

With this script, you can safely update Nextcloud: only the admin logs in to thoroughly test all features, check functionality, and decide—without pressure—whether it’s time to re-enable everyone or revert changes if needed. No accidental data loss, no unwanted surprises. This tool gives you full control, prevents headaches, and creates a smooth, worry-free update experience for both administrators and users. Try it and experience the confidence that comes from knowing your system and your users’ data are truly protected during every maintenance window.

---

## Features

- **User Management:** List, disable, and enable all users except admin to prevent data changes during maintenance.
- **Maintenance Mode:** Easily toggle Nextcloud maintenance mode on or off.
- **Safe Nextcloud Updates:** Update Nextcloud with backup confirmation.
- **Database Optimization:** Convert InnoDB tables to dynamic row format, required for Nextcloud 31+.
- **Automatic Configuration:** Reads database credentials directly from `config.php`, no manual input necessary.

---

## Requirements

- A Nextcloud installation (tested on Debian Buster, Bullseye, and Bookworm with Apache2, InnoDB, and PHP 8.0–8.3).  
  *If you use a different setup, please let us know!*
- Apache2 with InnoDB support
- PHP 8.0, 8.1, 8.2, or 8.3
- Nextcloud versions 27 to 31
- MySQL or MariaDB
- Bash shell with sudo rights
- The default Nextcloud web server user (`www-data`).  
  *If your setup uses a different user, adjust the script accordingly.*
- By default, the script uses `sudo -u www-data php occ`.  
  *On some systems you might need to use a specific PHP version, e.g., `php8.2`, instead of `php`. You can check your active PHP version with `php -i | grep "Loaded Configuration File"` and ensure it matches your Nextcloud setup.*

---

## Usage

Here’s how simple it is to get started:
```bash
git clone https://github.com/ffm3/nextcloud-maintenance.sh
cd nextcloud-maintenance.sh
chmod +x nextcloud-maintenance.sh
# (Optional) Edit the script to set your Nextcloud directory, for example:
#   NEXTCLOUD_DIR="/var/www/nextcloud"
sudo ./nextcloud-maintenance.sh
```

When you start the script, it asks for the admin username you use. That way, when you disable all users (option 2), the admin stays active. This lets you safely test everything as admin after updates before re-enabling all other users (option 3).

Automatic Configuration: The script automatically reads database credentials from config.php, so no manual input is needed.

After that, the script displays a menu with the following options:
```bash
Option 1: List all users and their status (disabled/enabled)
Option 2: Disable all users except admin
Option 3: Enable all users
Option 4: Turn maintenance mode ON
Option 5: Turn maintenance mode OFF
Option U: Perform a Nextcloud update
Option D: Convert database tables to the dynamic row format required from Nextcloud version 31+
```
This script uses the standard occ commands and automates common steps to make maintenance safe and worry-free.

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
