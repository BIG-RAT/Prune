//
//  Copyright 2026 Jamf. All rights reserved.
//

import Foundation

// Named async/await wrappers for each Platform API endpoint used by Prune.
// These use the modern versioned endpoints where available (openapi-jpapi.yaml),
// falling back to the Classic tunnel (openapi.yaml) for resources not yet in the modern API.
// app-installers/deployments is supported via getAppInstallerDeployments().

extension PlatformAPIClient {

    // MARK: - Modern endpoints (openapi-jpapi.yaml)

    func getPackages() async throws -> [[String: Any]] {
        try await getAll(version: "v1", resource: "packages")
    }

    func getPackage(id: String) async throws -> [String: Any] {
        try await get(version: "v1", resource: "packages", id: id)
    }

    func deletePackage(id: String) async throws {
        try await delete(version: "v1", resource: "packages", id: id)
    }

    func getScripts() async throws -> [[String: Any]] {
        try await getAll(version: "v1", resource: "scripts")
    }

    func getScript(id: String) async throws -> [String: Any] {
        try await get(version: "v1", resource: "scripts", id: id)
    }

    func deleteScript(id: String) async throws {
        try await delete(version: "v1", resource: "scripts", id: id)
    }

    func getComputerExtensionAttributes() async throws -> [[String: Any]] {
        try await getAll(version: "v1", resource: "computer-extension-attributes")
    }

    func getComputerExtensionAttribute(id: String) async throws -> [String: Any] {
        try await get(version: "v1", resource: "computer-extension-attributes", id: id)
    }

    func deleteComputerExtensionAttribute(id: String) async throws {
        try await delete(version: "v1", resource: "computer-extension-attributes", id: id)
    }

    func getMobileDeviceExtensionAttributes() async throws -> [[String: Any]] {
        try await getAll(version: "v1", resource: "mobile-device-extension-attributes")
    }

    func getMobileDeviceExtensionAttribute(id: String) async throws -> [String: Any] {
        try await get(version: "v1", resource: "mobile-device-extension-attributes", id: id)
    }

    func deleteMobileDeviceExtensionAttribute(id: String) async throws {
        try await delete(version: "v1", resource: "mobile-device-extension-attributes", id: id)
    }

    // Computer smart/static groups — modern API splits by type
    func getComputerSmartGroups() async throws -> [[String: Any]] {
        try await getAll(version: "v2", resource: "computer-groups/smart-groups")
    }

    func getComputerStaticGroups() async throws -> [[String: Any]] {
        try await getAll(version: "v2", resource: "computer-groups/static-groups")
    }

    func deleteComputerSmartGroup(id: String) async throws {
        try await delete(version: "v2", resource: "computer-groups/smart-groups", id: id)
    }

    func deleteComputerStaticGroup(id: String) async throws {
        try await delete(version: "v2", resource: "computer-groups/static-groups", id: id)
    }

    // Mobile device smart/static groups — modern API splits by type
    func getMobileDeviceSmartGroups() async throws -> [[String: Any]] {
        try await getAll(version: "v2", resource: "mobile-device-groups/smart-groups")
    }

    func getMobileDeviceStaticGroups() async throws -> [[String: Any]] {
        try await getAll(version: "v2", resource: "mobile-device-groups/static-groups")
    }

    func deleteMobileDeviceSmartGroup(id: String) async throws {
        try await delete(version: "v2", resource: "mobile-device-groups/smart-groups", id: id)
    }

    func deleteMobileDeviceStaticGroup(id: String) async throws {
        try await delete(version: "v2", resource: "mobile-device-groups/static-groups", id: id)
    }

    // Groups via classic tunnel — integer IDs and is_smart, matching Classic API format
    func getComputerGroupsClassic() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "computergroups")
    }

    func getMobileDeviceGroupsClassic() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "mobiledevicegroups")
    }

    func getComputerGroup(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "computergroups", id: id)
    }

    func getMobileDeviceGroup(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "mobiledevicegroups", id: id)
    }

    func getPatchSoftwareTitleConfigurations() async throws -> [[String: Any]] {
        try await getArray(version: "v2", resource: "patch-software-title-configurations")
    }

    func getPatchSoftwareTitleConfiguration(id: String) async throws -> [String: Any] {
        try await get(version: "v2", resource: "patch-software-title-configurations", id: id)
    }

    func getComputerPrestages() async throws -> [[String: Any]] {
        try await getAll(version: "v3", resource: "computer-prestages")
    }

    func getAppInstallerDeployments() async throws -> [[String: Any]] {
        try await getAll(version: "v1", resource: "app-installers/deployments")
    }

    func getBlueprints() async throws -> [[String: Any]] {
        try await getAllBlueprints(version: "v1", resource: "blueprints")
    }

    // Returns all groups (computer + mobile) from the unified device-groups endpoint.
    // Each result has "id" (UUID), "name", "deviceType" ("COMPUTER" or "MOBILE"), "groupType" ("SMART" or "STATIC").
    // Uses api/device-groups/v1 base URL (different from api/pro/).
    func getAllGroupsModern() async throws -> [[String: Any]] {
        try await getAllDeviceGroups(version: "v1", resource: "device-groups")
    }

    func getJamfProVersion() async throws -> String {
        let result = try await get(version: "v1", resource: "jamf-pro-version", id: "")
        return result["version"] as? String ?? ""
    }

    // MARK: - Classic tunnel endpoints (openapi.yaml)
    // Used for resources without a modern versioned equivalent.
    // Path pattern: /tenant/{tenantId}/{resource} (no version prefix)

    private func classicGetAll(resource: String) async throws -> [[String: Any]] {
        try await ensureToken()

        guard let url = URL(string: "\(classicBaseURL)/tenant/\(tenantId)/\(resource)") else {
            throw PlatformAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("Bearer \(JamfProServer.accessToken)", forHTTPHeaderField: "authorization")
        request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlatformAPIError.decodingError }
        guard httpSuccess.contains(http.statusCode) else { throw PlatformAPIError.httpError(http.statusCode) }

        // Classic endpoints return the list nested under a resource key, e.g. {"policies": [...]}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for value in json.values {
                if let list = value as? [[String: Any]] { return list }
            }
        }
        return []
    }

    private func classicGet(resource: String, id: String) async throws -> [String: Any] {
        try await ensureToken()

        guard let url = URL(string: "\(classicBaseURL)/tenant/\(tenantId)/\(resource)/id/\(id)") else {
            throw PlatformAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("Bearer \(JamfProServer.accessToken)", forHTTPHeaderField: "authorization")
        request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlatformAPIError.decodingError }
        guard httpSuccess.contains(http.statusCode) else { throw PlatformAPIError.httpError(http.statusCode) }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlatformAPIError.decodingError
        }
        return json
    }

    private func classicDelete(resource: String, id: String) async throws {
        try await ensureToken()

        guard let url = URL(string: "\(classicBaseURL)/tenant/\(tenantId)/\(resource)/id/\(id)") else {
            throw PlatformAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("Bearer \(JamfProServer.accessToken)", forHTTPHeaderField: "authorization")
        request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlatformAPIError.decodingError }
        guard httpSuccess.contains(http.statusCode) else { throw PlatformAPIError.httpError(http.statusCode) }
    }

    func getPrinters() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "printers")
    }

    func getPrinter(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "printers", id: id)
    }

    func deletePrinter(id: String) async throws {
        try await classicDelete(resource: "printers", id: id)
    }

    func getEbooks() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "ebooks")
    }

    func getEbook(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "ebooks", id: id)
    }

    func deleteEbook(id: String) async throws {
        try await classicDelete(resource: "ebooks", id: id)
    }

    func getClasses() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "classes")
    }

    func getClass(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "classes", id: id)
    }

    func deleteClass(id: String) async throws {
        try await classicDelete(resource: "classes", id: id)
    }

    func getOsxConfigurationProfiles() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "osxconfigurationprofiles")
    }

    func getOsxConfigurationProfile(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "osxconfigurationprofiles", id: id)
    }

    func deleteOsxConfigurationProfile(id: String) async throws {
        try await classicDelete(resource: "osxconfigurationprofiles", id: id)
    }

    func getMobileDeviceApplications() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "mobiledeviceapplications")
    }

    func getMobileDeviceApplication(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "mobiledeviceapplications", id: id)
    }

    func deleteMobileDeviceApplication(id: String) async throws {
        try await classicDelete(resource: "mobiledeviceapplications", id: id)
    }

    func getMobileDeviceConfigurationProfiles() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "mobiledeviceconfigurationprofiles")
    }

    func getMobileDeviceConfigurationProfile(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "mobiledeviceconfigurationprofiles", id: id)
    }

    func deleteMobileDeviceConfigurationProfile(id: String) async throws {
        try await classicDelete(resource: "mobiledeviceconfigurationprofiles", id: id)
    }

    func getMacApplications() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "macapplications")
    }

    func getMacApplication(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "macapplications", id: id)
    }

    func getPolicies() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "policies")
    }

    func getPolicy(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "policies", id: id)
    }

    func deletePolicy(id: String) async throws {
        try await classicDelete(resource: "policies", id: id)
    }

    func getRestrictedSoftware() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "restrictedsoftware")
    }

    func getRestrictedSoftwareItem(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "restrictedsoftware", id: id)
    }

    func deleteRestrictedSoftwareItem(id: String) async throws {
        try await classicDelete(resource: "restrictedsoftware", id: id)
    }

    func getAdvancedComputerSearches() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "advancedcomputersearches")
    }

    func getAdvancedComputerSearch(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "advancedcomputersearches", id: id)
    }

    func getAdvancedMobileDeviceSearches() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "advancedmobiledevicesearches")
    }

    func getAdvancedMobileDeviceSearch(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "advancedmobiledevicesearches", id: id)
    }

    func getPatchPolicies() async throws -> [[String: Any]] {
        try await classicGetAll(resource: "patchpolicies")
    }

    func getPatchPolicy(id: String) async throws -> [String: Any] {
        try await classicGet(resource: "patchpolicies", id: id)
    }
}
