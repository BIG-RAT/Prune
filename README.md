# Prune
Download: [Prune](https://github.com/BIG-RAT/prune/releases/download/current/prune.zip)

As your Jamf server ages it often accumulates more and more unused items, such as outdated packages, unscoped policies, mobile device apps...  Use Prune to help identify and remove those unused items.

![alt text](./images/pruneApp.png "Prune")

Once the list of unused items is generated you can edit it within the app.  If you see an object you wish to keep, say some policy, simply option+click the item in the list.  The item will be removed from the list, and hence not removed from the server.  Perhaps you'd like to review the item on the server before deleting, not a problem, just double click the item and you'll be taken to it on the Jamf server (may need to authenticate first).

![alt text](./images/edit.png "modify/review")

### Usage:
* Enter the server URL you wish to query along with valid credentials.  To simply generate a list you can use an auditor account.  To remove items an account with delete permissions is required.
* Select the items you'd like to scan.  You can option-click to select/de-select all the categories; packages, scripts, computer groups...
* Click Scan.
* Once the processing is complete review/edit the list.
* Click Remove if you wish to remove the listed items from the server.
* Click Export if you wish to save (to your Downloads folder) the lists of objects to remove for review/editing later.  These lists can then be imported into the application.
 
<br><hr><br>
### Usage Consideration
<table>
    <thead>
        <tr>
            <th>Object</th>
            <th>Check for Usage in</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Packages</td>
            <td>policies, patch policies, computer configurations</td>
        </tr>
        <tr>
            <td>Scripts</td>
            <td>policies, computer configurations,</td>
        </tr>
        <tr>
            <td>Computer Groups</td>
            <td>policies, computer configuration profiles, computer groups, eBooks</td>
        </tr>
        <tr>
            <td>Computer Profiles</td>
            <td>policies, computer configurations</td>
        </tr>
        <tr>
            <td>eBooks</td>
            <td>policies, patch policies, computer configurations, </td>
        </tr>
        <tr>
            <td>Policies</td>
            <td>policies, computer configurations</td>
        </tr>
        <tr>
            <td>Mobile Device Groups</td>
            <td>policies, computer configuration profiles, computer groups </td>
        </tr>
        <tr>
            <td>Mobile Device Profiles</td>
            <td>policies, computer configuration profiles, computer groups</td>
        </tr>
        <tr>
            <td>Classes</td>
            <td>policies, computer configurations,</td>
        </tr>
    </tbody>
</table>
<br><br><hr><br>

### Important:
This application deletes stuff, use with caution!  It is recommended you have a valid backup before deleting any objects.  You could either perform a database backup (if on prem) or use [Jamf Migrator](https://github.com/jamf/JamfMigrator) and export the (full) XML of all objects, or do both.
<br><br><hr><br>

### History:
2021-05-23 - Version 1.3.0: Added scan against eBooks and Classes.

2020-10-06 - Version 1.2.0: Guard against corrupt policies/scripts (having no name).  Added warning before deleting is initiated.  Write logging information to: ```~/Library/Containers/com.jamf.pse.prune/Data/Library/Logs/Prune.log```

