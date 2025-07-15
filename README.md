# FUWU-PS
Factorio Universal Windows Updater - PowerShell

This is an automated update script written in powershell to update factorio on Windows. 
It is not intended for use with Factorio installed using Steam.
Save this file to your factorio root folder.

To make it work just change the Paths & Release type in asterisk section at the top of the file:

# FUWU-PS
Factorio Universal Windows Updater - PowerShell

This is an automated update script written in powershell to update factorio on Windows. 
It is not intended for use with Factorio installed using Steam.
Save this file to your factorio root folder.

To make it work just change the Paths & Release type in asterisk section at the top of the file:

```powershell
# *************************** Change paths & Release type below ***************************

# === Switch for release type (stable or experimental) ===
# Change to "experimental" for experimental versions
$ReleaseType = "stable" # <- change this to set stable versions update or experimental versions update 

# Path Settings
$FactorioPath = "C:\Users\USERNAME\Desktop\STEAM_SERVERY\Factorio" # <- Set this path to your factorio root directory
$PlayerData = "C:\Users\USERNAME\Desktop\STEAM_SERVERY\Factorio\player-data.json" # <- Set this path to your player-data.json file (Default path in windows is AppData\Roaming\Factorio)
$ConfigPath = "C:\Users\USERNAME\Desktop\STEAM_SERVERY\Factorio\config\config.ini" # <- Set this path to your config.ini file (Default path in windows is AppData\Roaming\Factorio\config)

# *************************** Change paths & Release type above ***************************
```

To execute this file simply run Powershell in windows (ideally as administrator) and then change path to folder where you have this script saved (factorio root folder) using "cd" command and then run it with command:
.\FUWU_EN_NT.ps1 and wait until it updates to the latest version (experimental or stable).
