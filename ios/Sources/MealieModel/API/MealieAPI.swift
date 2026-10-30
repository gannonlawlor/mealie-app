import Foundation

private let logger = Log(category: "API")

func logInfo(_ message: String) {
    logger.info(message)
}

func logError(_ message: String) {
    logger.error(message)
}

public enum APIError: Error {
    case invalidURL
    case unauthorized
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case noData
}

public class MealieAPI: @unchecked Sendable {
    public static let shared = MealieAPI()

    var baseURL: String = ""
    var accessToken: String = ""

    /// Called on the main actor when a 401 persists after token refresh fails.
    public var onUnauthorized: @MainActor @Sendable () -> Void = {}

    private let session: URLSession
    private let authService: AuthService

    init(session: URLSession = .shared, authService: AuthService = .shared) {
        self.session = session
        self.authService = authService
    }

    public func configure(baseURL: String, token: String = "") {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.accessToken = token
    }

    public var isConfigured: Bool {
        !baseURL.isEmpty
    }

    // MARK: - Request Helpers

    /// Form bodies use different escaping rules from URL queries. In particular,
    /// literal plus and ampersand characters must not reach the form decoder.
    func loginRequest(email: String, password: String) throws -> URLRequest {
        guard let url = buildURL(path: "/api/auth/token") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoder.encode([("username", email), ("password", password)])
        return request
    }

    func buildURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        var urlString = "\(baseURL)\(path)"
        if let queryItems = queryItems, !queryItems.isEmpty {
            let queryString = queryItems.compactMap { item -> String? in
                guard let value = item.value else { return nil }
                let encodedName = item.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.name
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedName)=\(encodedValue)"
            }.joined(separator: "&")
            urlString += "?\(queryString)"
        }
        return URL(string: urlString)
    }

    func buildRequest(method: String, path: String, queryItems: [URLQueryItem]? = nil, body: Data? = nil, contentType: String = "application/json") throws -> URLRequest {
        guard let url = buildURL(path: path, queryItems: queryItems) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        if path == "/api/auth/refresh" || path == "/api/users/self" || path == "/api/app/about" {
            request.timeoutInterval = 30
        }
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    @MainActor private var refreshTask: (id: UUID, server: String, token: String, task: Task<Bool, Never>)?

    /// All requests rejected for the same session wait for its recovery. A second
    /// 401 must not sign the user out while the first request is still refreshing.
    @MainActor
    private func recoverSession(for request: URLRequest, server: String) async -> Bool {
        guard baseURL == server,
              let authorization = request.value(forHTTPHeaderField: "Authorization"),
              !accessToken.isEmpty else { return false }
        if authorization != "Bearer \(accessToken)" { return true }
        if let refreshTask, refreshTask.server == server, refreshTask.token == accessToken {
            return await refreshTask.task.value
        }
        let id = UUID()
        let task = Task { await self.attemptTokenRefresh() }
        refreshTask = (id, server, accessToken, task)
        defer { if refreshTask?.id == id { refreshTask = nil } }
        return await task.value
    }

    @MainActor
    private func attemptTokenRefresh() async -> Bool {
        let server = baseURL
        let expiredToken = accessToken

        // Try the refresh endpoint first
        do {
            let token: AuthToken = try await {
                let request = try buildRequest(method: "GET", path: "/api/auth/refresh")
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.unauthorized
                }
                return try JSONDecoder().decode(AuthToken.self, from: data)
            }()
            guard baseURL == server, accessToken == expiredToken else { return false }
            accessToken = token.accessToken
            authService.savedToken = token.accessToken
            logInfo("Token refreshed successfully")
            return true
        } catch {
            logInfo("Token refresh failed: \(error)")
        }

        // Refresh failed — try re-authenticating with saved credentials
        guard baseURL == server, accessToken == expiredToken else { return false }
        return await attemptReAuthentication(server: server, expiredToken: expiredToken)
    }

    @MainActor
    private func attemptReAuthentication(server: String, expiredToken: String) async -> Bool {
        guard let email = authService.savedEmail,
              let password = authService.savedPassword else {
            logInfo("No saved credentials for re-authentication")
            return false
        }

        do {
            let request = try loginRequest(email: email, password: password)

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                logInfo("Re-authentication failed with status code")
                return false
            }

            let token = try JSONDecoder().decode(AuthToken.self, from: data)
            guard baseURL == server, accessToken == expiredToken else { return false }
            accessToken = token.accessToken
            authService.savedToken = token.accessToken
            logInfo("Re-authentication successful")
            return true
        } catch {
            logInfo("Re-authentication failed: \(error)")
            return false
        }
    }

    private func rebuildRequest(_ original: URLRequest) -> URLRequest {
        var request = original
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    @MainActor
    private func notifyUnauthorized(for request: URLRequest, server: String) {
        // Ignore responses from a session that has since been cleared/replaced,
        // and never treat an unsuccessful manual login as session expiration.
        guard baseURL == server, !accessToken.isEmpty,
              request.value(forHTTPHeaderField: "Authorization") == "Bearer \(accessToken)" else { return }
        onUnauthorized()
    }

    func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        logInfo("\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")

        let server = baseURL
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        logInfo("Response: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 {
            if await recoverSession(for: request, server: server) {
                let retryRequest = rebuildRequest(request)
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.noData }
                if retryHttp.statusCode == 401 { await notifyUnauthorized(for: retryRequest, server: server); throw APIError.unauthorized }
                guard (200...299).contains(retryHttp.statusCode) else {
                    throw APIError.serverError(retryHttp.statusCode, String(data: retryData, encoding: .utf8) ?? "")
                }
                do { return try JSONDecoder().decode(T.self, from: retryData) }
                catch { throw APIError.decodingError(error) }
            }
            await notifyUnauthorized(for: request, server: server)
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(httpResponse.statusCode, body)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            logInfo("Decoding error for \(T.self): \(error)")
            logInfo("Response body: \(body.prefix(500))")
            throw APIError.decodingError(error)
        }
    }

    func performRaw(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let server = baseURL
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if httpResponse.statusCode == 401 {
            if await recoverSession(for: request, server: server) {
                let retryRequest = rebuildRequest(request)
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.noData }
                if retryHttp.statusCode == 401 { await notifyUnauthorized(for: retryRequest, server: server); throw APIError.unauthorized }
                guard (200...299).contains(retryHttp.statusCode) else {
                    throw APIError.serverError(retryHttp.statusCode, String(data: retryData, encoding: .utf8) ?? "")
                }
                return (retryData, retryHttp)
            }
            await notifyUnauthorized(for: request, server: server)
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(httpResponse.statusCode, body)
        }

        return (data, httpResponse)
    }

    // MARK: - Auth

    public func login(email: String, password: String) async throws -> AuthToken {
        return try await perform(loginRequest(email: email, password: password))
    }

    public func refreshToken() async throws -> AuthToken {
        let request = try buildRequest(method: "GET", path: "/api/auth/refresh")
        return try await perform(request)
    }

    public func getAppInfo() async throws -> AppInfo {
        let request = try buildRequest(method: "GET", path: "/api/app/about")
        return try await perform(request)
    }

    public func getCurrentUser() async throws -> User {
        let request = try buildRequest(method: "GET", path: "/api/users/self")
        return try await perform(request)
    }

    // MARK: - Recipes

    public func getRecipes(page: Int = 1, perPage: Int = 30, search: String? = nil, categories: [String]? = nil, tags: [String]? = nil, orderBy: String = "created_at", orderDirection: String = "desc") async throws -> RecipePaginatedResponse {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "perPage", value: String(perPage)),
            URLQueryItem(name: "orderBy", value: orderBy),
            URLQueryItem(name: "orderDirection", value: orderDirection),
        ]

        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let categories = categories, !categories.isEmpty {
            queryItems.append(URLQueryItem(name: "categories", value: categories.joined(separator: ",")))
        }
        if let tags = tags, !tags.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }

        let request = try buildRequest(method: "GET", path: "/api/recipes", queryItems: queryItems)
        return try await perform(request)
    }

    public func getRecipe(slug: String) async throws -> Recipe {
        let request = try buildRequest(method: "GET", path: "/api/recipes/\(slug)")
        return try await perform(request)
    }

    public func createRecipe(name: String) async throws -> String {
        let body = try JSONEncoder().encode(CreateRecipe(name: name))
        let request = try buildRequest(method: "POST", path: "/api/recipes", body: body)
        return try await perform(request)
    }

    public func createRecipeFromURL(url: String, includeTags: Bool = true) async throws -> String {
        let body = try JSONEncoder().encode(CreateRecipeFromURL(url: url, includeTags: includeTags))
        let request = try buildRequest(method: "POST", path: "/api/recipes/create/url", body: body)
        return try await perform(request)
    }

    public func updateRecipe(slug: String, data: Recipe) async throws -> Recipe {
        let body = try JSONEncoder().encode(data)
        let request = try buildRequest(method: "PATCH", path: "/api/recipes/\(slug)", body: body)
        return try await perform(request)
    }

    public func deleteRecipe(slug: String) async throws {
        let request = try buildRequest(method: "DELETE", path: "/api/recipes/\(slug)")
        let _ = try await performRaw(request)
    }

    public func recipeImageURL(recipeId: String, imageType: String = "min-original.webp") -> String {
        "\(baseURL)/api/media/recipes/\(recipeId)/images/\(imageType)"
    }

    public func uploadRecipeImage(slug: String, imageData: Data) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = buildURL(path: "/api/recipes/\(slug)/image") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"image\"; filename=\"recipe.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"extension\"\r\n\r\n".utf8))
        body.append(Data(".jpg".utf8))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        request.httpBody = body

        let _ = try await performRaw(request)
    }

    // MARK: - Favorites

    public func addFavorite(userId: String, slug: String) async throws {
        let request = try buildRequest(method: "POST", path: "/api/users/\(userId)/favorites/\(slug)")
        let _ = try await performRaw(request)
    }

    public func removeFavorite(userId: String, slug: String) async throws {
        let request = try buildRequest(method: "DELETE", path: "/api/users/\(userId)/favorites/\(slug)")
        let _ = try await performRaw(request)
    }

    // MARK: - Categories & Tags

    public func getCategories() async throws -> CategoryPaginatedResponse {
        let request = try buildRequest(method: "GET", path: "/api/organizers/categories", queryItems: [
            URLQueryItem(name: "perPage", value: "-1"),
        ])
        return try await perform(request)
    }

    public func getTags() async throws -> TagPaginatedResponse {
        let request = try buildRequest(method: "GET", path: "/api/organizers/tags", queryItems: [
            URLQueryItem(name: "perPage", value: "-1"),
        ])
        return try await perform(request)
    }

    // MARK: - Meal Plans

    public func getMealPlans(startDate: String, endDate: String) async throws -> MealPlanPaginatedResponse {
        let request = try buildRequest(method: "GET", path: "/api/households/mealplans", queryItems: [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
            URLQueryItem(name: "perPage", value: "-1"),
            URLQueryItem(name: "orderBy", value: "date"),
            URLQueryItem(name: "orderDirection", value: "asc"),
        ])
        return try await perform(request)
    }

    public func getTodayMealPlan() async throws -> [MealPlanEntry] {
        let request = try buildRequest(method: "GET", path: "/api/households/mealplans/today")
        return try await perform(request)
    }

    public func createMealPlan(_ plan: CreateMealPlan) async throws -> MealPlanEntry {
        let body = try JSONEncoder().encode(plan)
        let request = try buildRequest(method: "POST", path: "/api/households/mealplans", body: body)
        return try await perform(request)
    }

    public func deleteMealPlan(id: String) async throws {
        let request = try buildRequest(method: "DELETE", path: "/api/households/mealplans/\(id)")
        let _ = try await performRaw(request)
    }

    // MARK: - Shopping Lists

    public func getShoppingLists() async throws -> ShoppingListPaginatedResponse {
        let request = try buildRequest(method: "GET", path: "/api/households/shopping/lists", queryItems: [
            URLQueryItem(name: "perPage", value: "-1"),
        ])
        return try await perform(request)
    }

    public func getShoppingList(id: String) async throws -> ShoppingList {
        let request = try buildRequest(method: "GET", path: "/api/households/shopping/lists/\(id)")
        return try await perform(request)
    }

    public func createShoppingList(name: String) async throws -> ShoppingList {
        let body = try JSONEncoder().encode(CreateShoppingList(name: name))
        let request = try buildRequest(method: "POST", path: "/api/households/shopping/lists", body: body)
        return try await perform(request)
    }

    public func deleteShoppingList(id: String) async throws {
        let request = try buildRequest(method: "DELETE", path: "/api/households/shopping/lists/\(id)")
        let _ = try await performRaw(request)
    }

    public func addRecipeToShoppingList(listId: String, recipeId: String) async throws {
        let request = try buildRequest(method: "POST", path: "/api/households/shopping/lists/\(listId)/recipe/\(recipeId)")
        let _ = try await performRaw(request)
    }

    public func createShoppingListItem(_ item: CreateShoppingListItem) async throws -> ShoppingListItem {
        let body = try JSONEncoder().encode(item)
        let request = try buildRequest(method: "POST", path: "/api/households/shopping/items", body: body)
        return try await perform(request)
    }

    public func updateShoppingListItem(_ item: ShoppingListItem) async throws {
        let body = try JSONEncoder().encode([item])
        let request = try buildRequest(method: "PUT", path: "/api/households/shopping/items", body: body)
        let _ = try await performRaw(request)
    }

    public func deleteShoppingListItem(id: String) async throws {
        let request = try buildRequest(method: "DELETE", path: "/api/households/shopping/items", body: try JSONEncoder().encode([["itemId": id]]))
        let _ = try await performRaw(request)
    }
}
