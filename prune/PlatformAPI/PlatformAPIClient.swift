//
//  Copyright 2026 Jamf. All rights reserved.
//

import Foundation

// Base async/await client for the Jamf Platform API.
// Base URL: https://{region}.apigw.jamf.com/api/pro/{version}/tenant/{tenantId}/{resource}
// Auth: Bearer token from JamfProServer.accessToken (obtained via JamfPro.shared.getToken)

enum PlatformAPIError: Error {
    case invalidURL
    case httpError(Int)
    case decodingError
    case noToken
}

struct PlatformAPIClient {

    static let shared = PlatformAPIClient()
    private init() {}

    var baseURL: String {
        "https://\(JamfProServer.region).apigw.jamf.com/api/pro"
    }

    var classicBaseURL: String {
        "https://\(JamfProServer.region).apigw.jamf.com/api/proclassic"
    }

    var blueprintsBaseURL: String {
        "https://\(JamfProServer.region).apigw.jamf.com/api/blueprints"
    }

    var deviceGroupsBaseURL: String {
        "https://\(JamfProServer.region).apigw.jamf.com/api/device-groups"
    }

    // GET a paginated mobile device groups endpoint (different base URL: api/device-groups/).
    func getAllDeviceGroups(version: String, resource: String) async throws -> [[String: Any]] {
        try await ensureToken()

        var allResults: [[String: Any]] = []
        var page = 0
        let pageSize = 100

        repeat {
            var components = URLComponents(string: "\(deviceGroupsBaseURL)/\(version)/tenant/\(tenantId)/\(resource)")!
            components.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "page-size", value: "\(pageSize)"),
                URLQueryItem(name: "sort", value: "name"),
            ]
            guard let url = components.url else { throw PlatformAPIError.invalidURL }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "accept")
            request.setValue("Bearer \(JamfProServer.accessToken)", forHTTPHeaderField: "authorization")
            request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw PlatformAPIError.decodingError }
            guard httpSuccess.contains(http.statusCode) else { throw PlatformAPIError.httpError(http.statusCode) }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                throw PlatformAPIError.decodingError
            }

            allResults.append(contentsOf: results)

            let totalCount = json["totalCount"] as? Int ?? 0
            page += 1
            if allResults.count >= totalCount { break }
        } while true

        return allResults
    }

    // GET a paginated blueprints list endpoint (different base URL: api/blueprints/).
    func getAllBlueprints(version: String, resource: String) async throws -> [[String: Any]] {
        try await ensureToken()

        var allResults: [[String: Any]] = []
        var page = 0
        let pageSize = 100

        repeat {
            var components = URLComponents(string: "\(blueprintsBaseURL)/\(version)/tenant/\(tenantId)/\(resource)")!
            components.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "page-size", value: "\(pageSize)"),
                URLQueryItem(name: "sort", value: "name:asc"),
            ]
            guard let url = components.url else { throw PlatformAPIError.invalidURL }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "accept")
            request.setValue("Bearer \(JamfProServer.accessToken)", forHTTPHeaderField: "authorization")
            request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw PlatformAPIError.decodingError }
            guard httpSuccess.contains(http.statusCode) else { throw PlatformAPIError.httpError(http.statusCode) }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                throw PlatformAPIError.decodingError
            }

            allResults.append(contentsOf: results)

            let totalCount = json["totalCount"] as? Int ?? 0
            page += 1
            if allResults.count >= totalCount { break }
        } while true

        return allResults
    }

    // GET a single blueprint by id.
    func getBlueprint(id: String) async throws -> [String: Any] {
        try await ensureToken()

        guard let url = URL(string: "\(blueprintsBaseURL)/v1/tenant/\(tenantId)/blueprints/\(id)") else {
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

    var tenantId: String {
        JamfProServer.tenantId
    }

    // Ensures a valid token exists before making a call, reusing the existing getToken logic.
    func ensureToken() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            JamfPro.shared.getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { result in
                let (_, outcome) = result
                if outcome == "success" {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PlatformAPIError.noToken)
                }
            }
        }
    }

    // GET a paginated list endpoint, returning all results across pages.
    // version: e.g. "v1", "v2"
    // resource: e.g. "packages", "scripts"
    func getAll(version: String, resource: String, sort: String = "id:asc") async throws -> [[String: Any]] {
        try await ensureToken()

        var allResults: [[String: Any]] = []
        var page = 0
        let pageSize = 100

        repeat {
            var components = URLComponents(string: "\(baseURL)/\(version)/tenant/\(tenantId)/\(resource)")!
            components.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "page-size", value: "\(pageSize)"),
                URLQueryItem(name: "sort", value: sort),
            ]
            guard let url = components.url else { throw PlatformAPIError.invalidURL }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "accept")
            request.setValue("Bearer \(JamfProServer.accessToken)", forHTTPHeaderField: "authorization")
            request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw PlatformAPIError.decodingError }
            guard httpSuccess.contains(http.statusCode) else { throw PlatformAPIError.httpError(http.statusCode) }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                throw PlatformAPIError.decodingError
            }

            allResults.append(contentsOf: results)

            let totalCount = json["totalCount"] as? Int ?? 0
            page += 1
            if allResults.count >= totalCount { break }
        } while true

        return allResults
    }

    // GET a list endpoint that returns a bare JSON array (no results/totalCount envelope).
    func getArray(version: String, resource: String) async throws -> [[String: Any]] {
        try await ensureToken()

        guard let url = URL(string: "\(baseURL)/\(version)/tenant/\(tenantId)/\(resource)") else {
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

        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw PlatformAPIError.decodingError
        }
        return array
    }

    // GET a single record by id, or the resource itself if id is empty.
    func get(version: String, resource: String, id: String) async throws -> [String: Any] {
        try await ensureToken()

        let urlString = id.isEmpty
            ? "\(baseURL)/\(version)/tenant/\(tenantId)/\(resource)"
            : "\(baseURL)/\(version)/tenant/\(tenantId)/\(resource)/\(id)"
        guard let url = URL(string: urlString) else {
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

    // DELETE a single record by id.
    func delete(version: String, resource: String, id: String) async throws {
        try await ensureToken()

        guard let url = URL(string: "\(baseURL)/\(version)/tenant/\(tenantId)/\(resource)/\(id)") else {
            throw PlatformAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("Bearer \(JamfProServer.accessToken)", forHTTPHeaderField: "authorization")
        request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

        WriteToLog.shared.message("[delete] DELETE \(url.absoluteString)")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlatformAPIError.decodingError }
        WriteToLog.shared.message("[delete] \(resource)/\(id) → HTTP \(http.statusCode)")
        guard httpSuccess.contains(http.statusCode) else { throw PlatformAPIError.httpError(http.statusCode) }
    }
}
