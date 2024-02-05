#  Product Issues
Users and user groups not listed in policy scope. https://jamf.lightning.force.com/lightning/r/Product_Issue__c/a4g0h000001xgHfAAI/view (PI-005747)
    https://jamf.lightning.force.com/lightning/r/Product_Issue__c/a4g7V0000001oM6QAI/view (PI110713)
    
enabled/disabled state of Mac Apps is not visible in the api

Fix for cocoapods issue
https://stackoverflow.com/questions/75977278/intermediatebuildfilespath-uninstalledproducts-iphoneos-fmdb-framework-failed

App installers:
https://lhelou.jamfcloud.com/api/v1/app-installers/deployments
    gives scope (smart groups) of each app deployed.  only one group per app.
{
    "totalCount": 2,
    "results": [
        {
            "id": "1",
            "name": "Box Drive",
            "enabled": true,
            "deploymentType": "SELF_SERVICE",
            "updateBehavior": "AUTOMATIC",
            "site": {
                "id": "-1",
                "name": null
            },
            "smartGroup": {
                "id": "2059",
                "name": "fusion"
            },
            "category": {
                "id": "911",
                "name": "Apps"
            },
            "computerStatuses": {
                "installed": 0,
                "available": 1,
                "inProgress": 0,
                "failed": 0,
                "unqualified": 0
            },
            "app": {
                "id": "269",
                "latestVersion": "2.37.142",
                "selectedVersion": "",
                "bundleId": "com.box.desktop",
                "versionRemoved": false,
                "deployedVersion": "2.37.142",
                "titleAvailableInAis": true
            }
        },
        {
            "id": "2",
            "name": "1Password 8",
            "enabled": true,
            "deploymentType": "SELF_SERVICE",
            "updateBehavior": "AUTOMATIC",
            "site": {
                "id": "-1",
                "name": null
            },
            "smartGroup": {
                "id": "1904",
                "name": "10.12 - Sierra"
            },
            "category": {
                "id": "911",
                "name": "Apps"
            },
            "computerStatuses": {
                "installed": 0,
                "available": 0,
                "inProgress": 0,
                "failed": 0,
                "unqualified": 0
            },
            "app": {
                "id": "50F",
                "latestVersion": "8.10.24",
                "selectedVersion": "",
                "bundleId": "com.1password.1password",
                "versionRemoved": false,
                "deployedVersion": "8.10.24",
                "titleAvailableInAis": true
            }
        }
    ]
}
