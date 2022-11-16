# Prune
Download: [Prune](https://github.com/BIG-RAT/prune/releases/latest/download/prune.zip)

As your Jamf server ages it often accumulates more and more unused items, such as outdated packages, unscoped policies, mobile device apps...  Use Prune to help identify and remove those unused items.

![alt text](./images/pruneApp.png "Prune")

Once the list of unused items is generated you can edit it within the app.  If you see an object you wish to keep, say some policy, simply option+click the item in the list.  The item will be removed from the list, and hence not removed from the server.  Perhaps you'd like to review the item on the server before deleting, not a problem, just double click the item and you'll be taken to it on the Jamf server (may need to authenticate first).

![alt text](./images/edit.png "modify/review")

### Usage:
* Enter the server URL you wish to query along with valid credentials.  To simply generate a list you can use an auditor account.  To remove items an account with delete permissions is required.
* Select the item(s) you'd like to scan.  You can option-click to select/de-select all the categories; packages, scripts, computer groups...
* Click Scan.
* Once the processing is complete review/edit the list.
* Click Delete if you wish to delete the listed items from the server.
* Click Export if you wish to save (to your Downloads folder) the lists of objects to remove for review/editing later.  These lists can then be imported into the application.
 
<br><hr><br>
### Usage Calculations<br>

<table>
    <thead>
        <tr>
            <th>Object</th>
            <th>Determine Usage</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Packages</td>
            <td>Check for usage in policies, patch policies, computer prestages</td>
        </tr>
        <tr>
            <td>Scripts</td>
            <td>Check for usage in policies</td>
        </tr>
        <tr>
            <td>Computer Groups</td>
            <td>Check for usage in policies, computer configuration profiles, computer groups, eBooks, restricted software, advanced searches, enabled state</td>
        </tr>
        <tr>
            <td>Computer Profiles</td>
            <td>Check scope, computer prestages</td>
        </tr>
        <tr>
            <td>eBooks</td>
            <td>Check scope</td>
        </tr>
        <tr>
            <td>Policies</td>
            <td>Check scope</td>
        </tr>
        <tr>
            <td>Restricted Software</td>
            <td>Check scope for computer groups</td>
        </tr>
        <tr>
            <td>Computer Extension Attributes</td>
            <td>Check scope for computer groups, advanced searches, enabled state</td>
        </tr>
        <tr>
            <td>Mobile Device Groups</td>
            <td>Check for usage in mobile device apps, mobile device configuration profiles, mobile device groups, eBooks, classes</td>
        </tr>
        <tr>
            <td>Mobile Device Profiles</td>
            <td>Check scope</td>
        </tr>
        <tr>
            <td>Classes</td>
            <td>Check scope, only looks for students/student groups/mobile device assignements</td>
        </tr>
        <tr>
            <td>Mobile Device Extension Attributes</td>
            <td>Check scope for mobile device groups, advanced searches</td>
        </tr>
    </tbody>
</table>
<br><br>
<hr><br>

### Important:
* This application deletes stuff, <b>use with caution!</b>  It is recommended you have a valid backup before deleting any objects.  You could either perform a database backup (if on prem) or use [Jamf Migrator](https://github.com/jamf/JamfMigrator) and export the (full) XML of all objects, or do both.
* Policies scoped only to users and/or user groups will show as unused due to an issue with the API (it doesn't list the users or user groups).
* Bookmarks are not accessible via the API.  As a result groups that are only used to scope bookmarks will show as unused.

Logging information is written to: ```~/Library/Containers/com.jamf.pse.prune/Data/Library/Logs/Prune.log```

<br><hr><br>

### History:
2022-11-15 - v2.3.0: Fix issue where policies that are disabled and scoped were not showing up as unused (#27).

2022-11-15 - v2.3.0: List policies that are disabled and still scoped (#27).  List computer extension attributes that are disabled.  The item will have '    [disabled]' appended to its name.  Scan advanced searches (#26) for groups and extension attributes used as criteria.  Adjust URL to view unused scripts based on Jamf Pro version.

2022-07-27 - v2.2.5: Resolve crash when import  

2022-04-25 - v2.2.4: Fix crash when scanning only computer (configuration) profiles.  Add keyboard shortcut and menu bar item (View --> Logs Folder) to open logs folder.

2022-04-21 - v2.2.3: Fix some potential authentication issues.  Add deterministic progress wheel to provide current status while deleting items.

2022-02-17 - Add token authentication to the classic API for Jamf Pro 10.35+. Add feedback while items are being deleted from the Jamf Pro server. Resolved removal warning always showing 0 items (#13 ) and items not getting deleted when importing files (#14 ). Resolve crash that could occur if computer groups was not scanned, issue #15.  Resolve issue #16, packages in patch policies not being picked up.

2022-01-17 - Apologies in advance.  Layout changed as a dedicated login window was added.  Added restricted software as an item to query.  Changed Remove button to Delete.

2021-09-23 - Fixed issue where ebooks and classes were not getting deleted.

2021-09-23 - Updated URL used for a token request from Jamf Pro API, corrected extra comma in exported items, added export summary.

2021-05-30 - Scan computer prestages for packages and configuration profiles.  Remove check against computer configurations.  Fix app crash whem only classes is selected.  Fix issue of duplicate API calls.  Additional error handling.

2021-05-23 - Version 1.3.0: Added scan against eBooks and Classes.

2020-10-06 - Version 1.2.0: Guard against corrupt policies/scripts (having no name).  Added warning before deleting is initiated.  Write logging information to: ```~/Library/Containers/com.jamf.pse.prune/Data/Library/Logs/Prune.log```

