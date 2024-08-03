# Honeypot-Automation-and-Data-Collection

# Initial Setup
1. Replace 'your_password' (in the honeypot_setup.sh file) with the appropriate secure password for the MySQL user.

# After Running honeypot_setup.sh
1. Verify Installation
Check that Cowrie is running properly and logging attempts to the MySQL database.

Check Cowrie Service Status
```bash
sudo systemctl status cowrie
```
Ensure the service is active and running without errors.

2. Verify MySQL Logging
Log into MySQL and check if data is being recorded in the database.

```bash
sudo mysql -u honeypot_user -p

USE honeypot_data;
SELECT * FROM attempts;
```
You should see entries being logged here whenever an SSH connection attempts to connect to the honeypot.

3. Test the Honeypot
Perform a test SSH connection to your server to ensure Cowrie captures the attempt.

```bash
ssh user@Your_VPS_Server_IP_HERE
```
Then, recheck the MySQL table to see if the attempt was logged.

4. Monitor Logs
Monitor Cowrie and MySQL logs to ensure everything is functioning as expected.

Cowrie Logs
```bash
tail -f /opt/cowrie/var/log/cowrie/cowrie.log
```
MySQL Logs
```bash
tail -f /var/log/mysql/error.log
```
