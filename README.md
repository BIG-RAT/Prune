# Prune

![GitHub release (latest by date)](https://img.shields.io/github/v/release/BIG-RAT/prune?display_name=tag) ![GitHub all releases](https://img.shields.io/github/downloads/BIG-RAT/prune/total)  ![GitHub latest release](https://img.shields.io/github/downloads/BIG-RAT/prune/latest/total)
![GitHub issues](https://img.shields.io/github/issues-raw/BIG-RAT/prune) ![GitHub closed issues](https://img.shields.io/github/issues-closed-raw/BIG-RAT/prune) ![GitHub pull requests](https://img.shields.io/github/issues-pr-raw/BIG-RAT/jamfcpr) ![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed-raw/BIG-RAT/prune)

## What is Prune?

**Prune** is a macOS application that helps you clean up your Jamf Pro server by identifying and removing unused items. As your Jamf server ages, it often accumulates outdated packages, unscoped policies, mobile device apps, and other unused objects. Prune scans your server to find these items and helps you safely remove them.

### Quick Download

👉 **[Download Prune (Latest Release)](https://github.com/BIG-RAT/prune/releases/latest/download/prune.zip)**

---

![Prune Application Interface](./images/pruneApp.png "Prune Application")

## How It Works

1. **Scan**: Prune connects to your Jamf Pro server and scans for unused items across multiple object types.
2. **Review**: The app generates a list of potentially unused items that you can review and edit.
3. **Edit**: Remove items from the deletion list or open them directly on your Jamf server.
4. **Delete**: Once you're confident, delete the unused items to clean up your server.

> **⚠️ Error Handling**: If the server indicates an error while reading an object, it will be logged and you'll receive an alert indicating the results may be inaccurate.

![Warning Alert](./images/pruneWarning.png "Warning Alert")

### Editing Your List

Once the list of unused items is generated, you can edit it directly within the app:

- **Remove an item from the deletion list**: Option-click the item to keep it (it won't be deleted from the server)
- **Review an item on the server**: Double-click any item to open it directly on your Jamf server (you may need to authenticate first)

![Edit Interface](./images/edit.png "Editing and Review Interface")

## 📖 Usage Guide

### Step-by-Step Instructions

1. **Connect to Your Server**
   - Enter your Jamf Pro server URL and credentials
        - **💡 Recommended**: Use [API Client Credentials](#setting-up-api-client-credentials) for authentication instead of user accounts
   - To generate a list only: Use an auditor account (read-only) or client credentials with read permissions
   - To delete items: Use an account with delete permissions or client credentials with delete permissions

2. **Select Object Types to Scan**
   - Choose the object types you want to scan (packages, scripts, computer groups, policies, etc.)
   - **Tip**: Option-click to select or deselect all object types at once

3. **Start the Scan**
   - Click the **Scan** button
   - Wait for Prune to analyze your server and identify unused items

4. **Review and Edit the Results**
   - Review the generated list of unused items
   - **Option-click** any item to remove it from the deletion list (keeps it on your server)
   - **Double-click** any item to open it on your Jamf server for detailed review

5. **Delete Items** (Optional)
   - Click **Delete** to remove the listed items from your server
   - To delete only a specific object type: Change the **View** option to the desired type, then click **Delete**

6. **Export Results** (Optional)
   - Click **Export** to save lists to your Downloads folder (one file per object type)
   - These files can be imported later by clicking the import button or dragging the file onto it
   - **Option-click Export** to export all items to a single CSV file

### ⚠️ Important Notes

- **Blueprints are not scanned**: Groups used only in blueprints will show as unused since blueprints aren't analyzed.

---

<a id="setting-up-api-client-credentials"></a>
## 🔑 Setting Up API Client Credentials

API Client Credentials are the recommended method for authenticating with your Jamf Pro server. They provide better security and are more suitable for programmatic access than user accounts.

### Step-by-Step Setup

1. **Log into Jamf Pro**
   - Open your Jamf Pro web interface
   - Sign in with an account that has administrative privileges

2. **Navigate to Client Credentials**
   - Go to **Settings** (⚙️)
   - Select **API roles and clients** from the System Settings section

3. **Create a New API Role**
   - Click the **New** button (+) to create a new API role
   - Fill in the required information:
     - **Display Name**: Enter a descriptive name (e.g., "Prune.app - Read & Delete Objects")
     - **Privileges**: Choose the appropriate privileges based on your needs:
       - **For read-only access** (scanning only): Grant Read permissions for all object types you want to scan
       - **For full functionality** (scanning and deleting): Grant both Read and Delete permissions for the object types you want to manage
   
   #### Complete List of Required Privileges for Full Functionality
   
   If you want to use Prune with all available object types, you'll need to grant the following privileges in your API role:
   
   - Delete Static Computer Groups
   - Read iOS Configuration Profiles
   - Delete macOS Configuration Profiles
   - Read Static Computer Groups
   - Read Mobile Device PreStage Enrollments
   - Delete Printers
   - Read Mac Applications
   - Delete Mobile Device Applications
   - Read macOS Configuration Profiles
   - Delete iOS Configuration Profiles
   - Delete Scripts
   - Delete eBooks
   - Read Mobile Device Extension Attributes
   - Delete Mac Applications
   - Delete Computer Extension Attributes
   - Delete Mobile Device Extension Attributes
   - Delete Static Mobile Device Groups
   - Read Scripts
   - Read Computer PreStage Enrollments
   - Delete Smart Computer Groups
   - Delete Policies
   - Read Static Mobile Device Groups
   - Read Mobile Device Applications
   - Read Printers
   - Delete Packages
   - Read Restricted Software
   - Read Classes
   - Read Smart Computer Groups
   - Delete Restricted Software
   - Read Smart Mobile Device Groups
   - Read Packages
   - Read Computer Extension Attributes
   - Read eBooks
   - Delete Smart Mobile Device Groups
   - Delete Classes
   - Read Policies
   
   > **Tip**: You can create separate API roles for different use cases (e.g., one for read-only scanning and one for full delete access) and assign them to different API clients as needed.
        

4. **Create a New API Client**
   - Navigate back to the **API roles and clients** section in Jamf Pro
   - On the **API Clients** tab, click the **New** button (+) to create a new API client
    - Fill in the required information:
        - **Display Name**: Enter a descriptive name (e.g., "Prune.app")
        - **API roles**: Select the API role you created in the previous step
    - Enable API client: Click the **Enable API client** button
    - Click **Save** to create the client

5. **Generate Client Secret and Copy Credentials**
   - Click **Generate client secret** > **Create secret**
   - **Important**: Copy the **Client ID** and **Client Secret** immediately
   - The Client Secret will only be displayed once and cannot be retrieved later
   - Store these credentials securely (consider using a password manager)

6. **Use in Prune**
   - When connecting in Prune, check the box for **Use API client**:
     - Paste your **Client ID** and **Client Secret** into the relevant fields

---

## 🔍 How Prune Determines Usage

Prune analyzes each object type by checking specific usage locations in your Jamf Pro server. The table below explains how each object type is evaluated:

| Object Type | How Usage is Determined |
|------------|------------------------|
| **Packages** | Checked for usage in policies, patch policies, and computer prestages |
| **Scripts** | Checked for usage in policies |
| **Computer Groups** | Checked for usage in policies, computer configuration profiles, computer groups, eBooks, restricted software, advanced searches, app installers, and enabled state |
| **Computer Profiles** | Checked for scope and usage in computer prestages |
| **Policies** | Checked for scope |
| **Printers** | Checked for usage in policies and macOS configuration profiles |
| **Mac Apps** | Checked for scope |
| **Restricted Software** | Checked for scope of computer groups |
| **Computer Extension Attributes** | Checked for scope of computer groups, advanced searches (including display tab), and enabled state |
| **eBooks** | Checked for scope |
| **Mobile Device Groups** | Checked for usage in mobile device apps, mobile device configuration profiles, mobile device groups, eBooks, and classes |
| **Mobile Device Profiles** | Checked for scope |
| **Classes** | Checked for scope (only looks for students/student groups/mobile device assignments) |
| **Mobile Device Extension Attributes** | Checked for scope of mobile device groups and advanced searches |

---

## ⚠️ Important Warnings

### 🔴 Use with Caution!

**This application deletes items from your Jamf Pro server. Always use with caution!**

1. **Backup First**: It's **strongly recommended** to have a valid backup before deleting any objects. You can:
   - Perform a database backup (if on-premise)
   - Use [Replicator](https://github.com/jamf/Replicator) to export the full XML of all objects
   - Or do both for maximum safety

### Known Limitations

Prune may identify some items as unused that are actually in use due to API limitations:

- **Policies scoped only to users/user groups**: Will show as unused because the API doesn't list users or user groups in policy scopes
- **Mac Apps**: Enabled/disabled state is not available via the API, so this isn't used to determine usage
- **Bookmarks**: Not accessible via the API, so groups used only to scope bookmarks will show as unused

### Logging

Logging information is written to:
```
~/Library/Containers/com.jamf.pse.prune/Data/Library/Logs/Prune.log
```

You can access this folder through the menu bar: **View → Logs Folder**

---

## 📊 Analytics & Privacy

Prune collects basic hardware, OS, and application usage data and sends it **anonymously** to [TelemetryDeck](https://telemetrydeck.com) to help improve the application. You can opt out at any time by clicking **"Opt out of analytics"** at the bottom of the **"About Prune"** window.

---

## 📜 Version History

### v3.4.0 (2025-12-24)
- Add basic hardware, OS, and application usage collection
- Data is sent anonymously to [TelemetryDeck](https://telemetrydeck.com) to aid in development
- View 'About Prune' to opt out of sending data
- Address items in issue #55
- Add ability to remove scoped disabled policies

### v3.3.0 (2025-04-14)
- Include printers as an available object to scan
- Update for Sequoia and accessing shared data
- Misc fixes and cleanup

### v3.2.2 (2024-09-26)
- Fix crash when exporting after an import
- Fix title being truncated (full name now appears as a tooltip)

### v3.2.1 (2024-02-09)
- Query App Installers for groups used for scoping

### v3.2.0 (2024-02-04)
- Update login window
- Add support for bearer token authentication
- Provide alert if some lookups fail, which may result in inaccurate results

### v3.1.1 (2023-10-15)
- Fix issue #42
- Updated token refresh process to address issue #41
- Improved logging

### v3.1.0 (2023-09-16)
- Fix issue #39: double quotes in display name
- Better handling of bearer token expiration
- Fix export to CSV for policies
- Enable sharing of keychain items with other apps by the same developer

### v3.0.2 (2023-07-14)
- Guard against faulty package configurations in computer prestages
- Check for extension attributes used only on the display tab of advanced searches

### v3.0.1 (2023-04-07)
- Updated logging to prevent potential looping

### v3.0.0 (2023-03-21)
- Updated UI
- Add ability to export results to a CSV (Option-click Export)

### v2.4.0 (2023-03-08)
- Add scanning of Mac Apps

### v2.3.3 (2022-11-18)
- Fix issue where extension attributes used as criteria in smart groups were listed as unused

### v2.3.2 (2022-11-18)
- Fix computer/mobile device extension attributes not deleting (#29)

### v2.3.1 (2022-11-16)
- Fix issue where policies that are disabled and scoped were not showing up as unused (#27)

### v2.3.0 (2022-11-15)
- List policies that are disabled and still scoped (#27)
- List computer extension attributes that are disabled (marked with `[disabled]`)
- Scan advanced searches (#26) for groups and extension attributes used as criteria
- Adjust URL to view unused scripts based on Jamf Pro version

### v2.2.5 (2022-07-27)
- Resolve crash when importing

### v2.2.4 (2022-04-25)
- Fix crash when scanning only computer (configuration) profiles
- Add keyboard shortcut and menu bar item (View → Logs Folder) to open logs folder

### v2.2.3 (2022-04-21)
- Fix some potential authentication issues
- Add deterministic progress wheel to show current status while deleting items

### v2.2.2 (2022-02-17)
- Add token authentication to the classic API for Jamf Pro 10.35+
- Add feedback while items are being deleted from the Jamf Pro server
- Fix removal warning always showing 0 items (#13)
- Fix items not getting deleted when importing files (#14)
- Fix crash that could occur if computer groups were not scanned (#15)
- Fix packages in patch policies not being picked up (#16)

### v2.2.1 (2022-01-17)
- Layout changed with dedicated login window
- Added restricted software as an item to query
- Changed Remove button to Delete

### v1.3.1 (2021-09-23)
- Fixed issue where eBooks and classes were not getting deleted
- Updated URL used for token request from Jamf Pro API
- Corrected extra comma in exported items
- Added export summary

### v1.3.0 (2021-05-30)
- Scan computer prestages for packages and configuration profiles
- Remove check against computer configurations
- Fix app crash when only classes is selected
- Fix issue of duplicate API calls
- Additional error handling

### v1.3.0 (2021-05-23)
- Added scan against eBooks and Classes

### v1.2.0 (2020-10-06)
- Guard against corrupt policies/scripts (having no name)
- Added warning before deleting is initiated
- Write logging information to `~/Library/Containers/com.jamf.pse.prune/Data/Library/Logs/Prune.log`

