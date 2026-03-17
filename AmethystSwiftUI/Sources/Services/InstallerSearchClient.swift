import Foundation

enum InstallerSearchError: Error, LocalizedError {
    case invalidQuery
    case missingCurseForgeKey
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Please enter a search query."
        case .missingCurseForgeKey:
            return "CurseForge API key is required. Add it in Settings."
        case .invalidResponse:
            return "Unexpected installer response."
        }
    }
}

struct InstallerSearchClient {
    func search(
        source: InstallerSource,
        query: String,
        curseForgeApiKey: String
    ) async throws -> [InstallerResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw InstallerSearchError.invalidQuery
        }

        switch source {
        case .modrinth:
            return try await searchModrinth(query: trimmedQuery)
        case .curseforge:
            return try await searchCurseForge(query: trimmedQuery, apiKey: curseForgeApiKey)
        }
    }

    private func searchModrinth(query: String) async throws -> [InstallerResult] {
        var components = URLComponents(string: "https://api.modrinth.com/v2/search")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "20")
        ]
        guard let url = components?.url else {
            throw InstallerSearchError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw InstallerSearchError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ModrinthSearchResponse.self, from: data)
        return decoded.hits.map {
            InstallerResult(
                title: $0.title,
                subtitle: $0.description ?? "Modrinth item"
            )
        }
    }

    private func searchCurseForge(query: String, apiKey: String) async throws -> [InstallerResult] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw InstallerSearchError.missingCurseForgeKey
        }

        var components = URLComponents(string: "https://api.curseforge.com/v1/mods/search")
        components?.queryItems = [
            URLQueryItem(name: "gameId", value: "432"),
            URLQueryItem(name: "searchFilter", value: query),
            URLQueryItem(name: "pageSize", value: "20")
        ]
        guard let url = components?.url else {
            throw InstallerSearchError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(trimmedKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw InstallerSearchError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(CurseForgeSearchResponse.self, from: data)
        return decoded.data.map {
            InstallerResult(
                title: $0.name,
                subtitle: $0.summary ?? "CurseForge mod"
            )
        }
    }
}

private struct ModrinthSearchResponse: Decodable {
    let hits: [ModrinthHit]
}

private struct ModrinthHit: Decodable {
    let title: String
    let description: String?
}

private struct CurseForgeSearchResponse: Decodable {
    let data: [CurseForgeMod]
}

private struct CurseForgeMod: Decodable {
    let name: String
    let summary: String?
}
