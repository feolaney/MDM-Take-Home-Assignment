# Section 1 - Packaging Task
## macOS/Jamf
Deploying Chrome to macOS, normally, I wouldn’t create an additional package on the macOS side. The package provided by Google is already a deployable PKG that installs silently when executed from the command line or deployed through an MDM. It installs correctly in the system context with proper permissions.

Additionally, both Jamf and macOS natively capture sufficient logs, a condensed version of which can be viewed directly in the Jamf Pro console whenever a policy runs. Locally on the computer, more verbose logs can be found at:
- /var/log/jamf.log
- /var/log/install.log

On the macOS side, I did something a little different, something I wouldn’t normally do when deploying Google Chrome from an MDM like Jamf. As I mentioned before, you can simply upload the provided PKG into the MDM and deploy it as is. However, to better align with the requirements of the assignment, I placed the PKG inside a custom package I created. This package includes a post-install script that collects verbose logs from the install process, which runs after the PKG is placed in a temporary directory on the Mac.

Again, this level of customization is overkill for deploying Google Chrome, but it does help demonstrate how to handle a custom app installation that might require additional steps and techniques.

## Windows/Intune
On the Windows side, I created an Intune package that’s deployed through a Win32 app policy in Intune, which is what Microsoft recommends for applications installed during or after the Autopilot process. Typically, application deployments should stay within the new Windows App Store deployment model, but in cases like this, where Google Chrome isn’t available through the store, my recommendation is to package it into an Intune package and deploy it as a Win32 app. I’ve provided the file and the necessary commands used to deploy the application when creating the Win32 app policy in Intune.

A similar approach could be used for logging on the Windows side, just as I did with Jamf. A PowerShell script could be created and invoked as part of the install command within the Intune application policy, allowing you to build similar log-capturing logic that writes to a local log file, as I did with the custom package for macOS. However, this is unnecessary since all of that information is already recorded in the Event Viewer and Intune logs, both of which can be collected remotely using the Collect Diagnostics tool in Intune. I have included though in the README a command that could be used to capture logging in a log file I designated  at C:\Windows\Temp\Chrome_Install.log if the extra logging was wanted.

# Section 2 - Scripting and Automation
Both scripts include instructions in their respective README files. I also created a PKG for the Mac script, which places the wallpaper image in a location accessible to the script. If this is something that is going to be tested there is a companion pkg I have placed with the script that will need to be run to deploy the wallpaper. (I recommend testing this script (Romi would like this) although if tested on a prod machine I did include a reverse script to unload and remove the launch agent).

On the macOS side, the script should be deployed with a PPPC profile since it uses AppleScript to set the wallpaper for all users. Without that, users will see a permissions prompt unless it’s suppressed through a PPPC configuration profile.

For Windows, the script is designed to prompt for an image. To test it, you just need to provide an image file when the script runs.

# Section 3 - Endpoint Policy Rollout Strategy
This is just a markdown file with my rollout strategy

# Section 4 - API Automation 
This one is straightforward, python script (python3) that uses GitHub REST API using the public REST API to iterate through each page where the org is 'macadmins' and places desired information into a csv for entries that are 30 days or newer.