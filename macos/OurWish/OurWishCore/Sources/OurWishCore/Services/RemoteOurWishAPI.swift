import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct RemoteErrorBody: Decodable {
    struct ErrorPayload: Decodable {
        let message: String
    }

    let error: ErrorPayload
}

private struct RemoteLoginResponse: Decodable {
    let token: String
    let user: RemoteUser
}

private struct RemoteUser: Decodable {
    let id: Int64
    let firstName: String
    let lastName: String
    let displayName: String
    let email: String
    let bio: String?
    let imageURL: String?
}

private struct RemoteWishList: Decodable {
    let id: Int64
    let name: String
}

/// Holds the item's metadata fields as a single `WishListItemMetadata` (decoded by
/// delegating to the same flat JSON object it's already reading its own scalar fields
/// from) instead of separately re-declaring all 15 of them — see that type's `Codable`
/// conformance, which is also what the server's `ItemDTO` delegates to on the way out.
private struct RemoteItem: Decodable {
    let id: Int64
    let productName: String
    let price: Double
    let quantity: Int
    let url: String?
    let isPurchased: Bool
    let isHidden: Bool
    let imageURL: String?
    let metadata: WishListItemMetadata

    private enum CodingKeys: String, CodingKey {
        case id, productName, price, quantity, url, isPurchased, isHidden, imageURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        productName = try container.decode(String.self, forKey: .productName)
        price = try container.decode(Double.self, forKey: .price)
        quantity = try container.decode(Int.self, forKey: .quantity)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        isPurchased = try container.decode(Bool.self, forKey: .isPurchased)
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        metadata = try WishListItemMetadata(from: decoder)
    }
}

private struct RemoteItemsResponse: Decodable {
    let active: [RemoteItem]
    let purchased: [RemoteItem]
}

private struct RemoteCollaborativeList: Decodable {
    let id: Int64
    let name: String
    let partnerName: String
}

private struct RemotePartner: Decodable {
    let email: String
    let displayName: String
}

private struct RemoteUserCount: Decodable {
    let count: Int
}

public struct RemoteAPIError: LocalizedError {
    public let message: String

    public var errorDescription: String? {
        message
    }
}

public actor RemoteOurWishAPI: AuthStoreService, WishListStoreService, CollaborativeStoreService {
    private let baseURL: URL
    private let session: URLSession
    private var bearerToken: String?

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func userCount() async throws -> Int {
        let response: RemoteUserCount = try await request(path: "/api/v1/auth/user-count")
        return response.count
    }

    public func login(email: String, password: String) async throws -> User {
        let response: RemoteLoginResponse = try await request(
            path: "/api/v1/auth/login",
            method: "POST",
            body: ["email": email, "password": password]
        )
        bearerToken = response.token
        return try await makeUser(from: response.user)
    }

    public func logout() async throws {
        guard bearerToken != nil else { return }
        defer {
            bearerToken = nil
        }
        try await requestNoContent(path: "/api/v1/auth/logout", method: "POST")
    }

    public func register(firstName: String, lastName: String, email: String, password: String) async throws {
        let _: RemoteUser = try await request(
            path: "/api/v1/auth/register",
            method: "POST",
            body: [
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "password": password,
            ]
        )
    }

    public func updateProfile(
        userId: Int64,
        firstName: String,
        lastName: String,
        displayName: String,
        email: String,
        bio: String?,
        profileImageData: Data?
    ) async throws -> User {
        _ = userId
        let response: RemoteUser = try await request(
            path: "/api/v1/auth/profile",
            method: "PUT",
            body: [
                "firstName": firstName,
                "lastName": lastName,
                "displayName": displayName,
                "email": email,
                "bio": bio,
                "imageBase64": profileImageData?.base64EncodedString(),
            ]
        )
        return try await makeUser(from: response)
    }

    public func changePassword(userId: Int64, currentPassword: String, newPassword: String) async throws {
        _ = userId
        try await requestNoContent(
            path: "/api/v1/auth/password",
            method: "PUT",
            body: ["currentPassword": currentPassword, "newPassword": newPassword]
        )
    }

    public func deleteAccount(userId: Int64) async throws {
        _ = userId
        try await requestNoContent(path: "/api/v1/auth/account", method: "DELETE")
        bearerToken = nil
    }

    public func wishLists(for userId: Int64) async throws -> [WishList] {
        let response: [RemoteWishList] = try await request(path: "/api/v1/wishlists")
        return response.map { WishList(id: $0.id, userId: userId, name: $0.name) }
    }

    public func createWishList(userId: Int64, name: String) async throws -> WishList {
        let response: RemoteWishList = try await request(
            path: "/api/v1/wishlists",
            method: "POST",
            body: ["name": name]
        )
        return WishList(id: response.id, userId: userId, name: response.name)
    }

    public func renameWishList(listId: Int64, userId: Int64, name: String) async throws {
        _ = userId
        try await requestNoContent(path: "/api/v1/wishlists/\(listId)", method: "PUT", body: ["name": name])
    }

    public func deleteWishList(listId: Int64, userId: Int64) async throws {
        _ = userId
        try await requestNoContent(path: "/api/v1/wishlists/\(listId)", method: "DELETE")
    }

    public func wishListItems(listId: Int64, userId: Int64, purchased: Bool) async throws -> [WishListItem] {
        let response: RemoteItemsResponse = try await request(path: "/api/v1/wishlists/\(listId)/items")
        let source = purchased ? response.purchased : response.active
        return await mapWishListItems(source, listId: listId, userId: userId)
    }

    public func addWishListItem(
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        imageData: Data?,
        metadata: WishListItemMetadata
    ) async throws -> WishListItem {
        var body: [String: Any?] = [
            "productName": productName,
            "price": price,
            "quantity": quantity,
            "url": url,
            "imageBase64": imageData?.base64EncodedString(),
            "clientResolvedImage": true,
        ]
        for (key, value) in try metadataJSONFields(metadata) {
            body[key] = value
        }
        let response: RemoteItem = try await request(
            path: "/api/v1/wishlists/\(listId)/items",
            method: "POST",
            body: body
        )
        return await makeWishListItem(from: response, listId: listId, userId: userId)
    }

    public func updateWishListItem(
        itemId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        metadata: WishListItemMetadata
    ) async throws {
        _ = userId
        var body: [String: Any?] = [
            "productName": productName,
            "price": price,
            "quantity": quantity,
            "url": url,
        ]
        for (key, value) in try metadataJSONFields(metadata) {
            body[key] = value
        }
        try await requestNoContent(path: "/api/v1/items/\(itemId)", method: "PUT", body: body)
    }

    public func setWishListItemPurchased(itemId: Int64, userId: Int64, isPurchased: Bool) async throws {
        _ = userId
        try await requestNoContent(
            path: "/api/v1/items/\(itemId)/purchase",
            method: "PUT",
            body: ["isPurchased": isPurchased]
        )
    }

    public func setWishListItemHidden(itemId: Int64, userId: Int64, isHidden: Bool) async throws {
        _ = userId
        try await requestNoContent(
            path: "/api/v1/items/\(itemId)/hidden",
            method: "PUT",
            body: ["isHidden": isHidden]
        )
    }

    public func deleteWishListItem(itemId: Int64, userId: Int64) async throws {
        _ = userId
        try await requestNoContent(path: "/api/v1/items/\(itemId)", method: "DELETE")
    }

    public func partners(excluding userId: Int64) async throws -> [User] {
        _ = userId
        let response: [RemotePartner] = try await request(path: "/api/v1/collaborative/partners")
        return response.enumerated().map { index, partner in
            User(
                id: Int64(-1 - index),
                firstName: partner.displayName,
                lastName: "",
                displayName: partner.displayName,
                email: partner.email,
                passwordHash: "",
                bio: nil,
                profileImageData: nil
            )
        }
    }

    public func collaborativeLists(for userId: Int64) async throws -> [CollaborativeListWithPartner] {
        let response: [RemoteCollaborativeList] = try await request(path: "/api/v1/collaborative/lists")
        return response.map {
            CollaborativeListWithPartner(
                id: $0.id,
                name: $0.name,
                user1Id: userId,
                user2Id: 0,
                partnerName: $0.partnerName
            )
        }
    }

    public func createCollaborativeList(currentUserId: Int64, partnerEmail: String, name: String) async throws -> CollaborativeList {
        let response: RemoteCollaborativeList = try await request(
            path: "/api/v1/collaborative/lists",
            method: "POST",
            body: ["partnerEmail": partnerEmail, "name": name]
        )
        return CollaborativeList(id: response.id, name: response.name, user1Id: currentUserId, user2Id: 0)
    }

    public func deleteCollaborativeList(listId: Int64, userId: Int64) async throws {
        _ = userId
        try await requestNoContent(path: "/api/v1/collaborative/lists/\(listId)", method: "DELETE")
    }

    public func collaborativeItems(listId: Int64, userId: Int64, purchased: Bool) async throws -> [CollaborativeItem] {
        let response: RemoteItemsResponse = try await request(path: "/api/v1/collaborative/lists/\(listId)/items")
        let source = purchased ? response.purchased : response.active
        return await mapCollaborativeItems(source, listId: listId)
    }

    public func addCollaborativeItem(
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        imageData: Data?,
        metadata: WishListItemMetadata
    ) async throws -> CollaborativeItem {
        _ = userId
        var body: [String: Any?] = [
            "productName": productName,
            "price": price,
            "quantity": quantity,
            "url": url,
            "imageBase64": imageData?.base64EncodedString(),
            "clientResolvedImage": true,
        ]
        for (key, value) in try metadataJSONFields(metadata) {
            body[key] = value
        }
        let response: RemoteItem = try await request(
            path: "/api/v1/collaborative/lists/\(listId)/items",
            method: "POST",
            body: body
        )
        return await makeCollaborativeItem(from: response, listId: listId)
    }

    public func updateCollaborativeItem(
        itemId: Int64,
        listId: Int64,
        userId: Int64,
        productName: String,
        price: Double,
        quantity: Int,
        url: String?,
        metadata: WishListItemMetadata
    ) async throws {
        _ = userId
        var body: [String: Any?] = [
            "productName": productName,
            "price": price,
            "quantity": quantity,
            "url": url,
        ]
        for (key, value) in try metadataJSONFields(metadata) {
            body[key] = value
        }
        try await requestNoContent(
            path: "/api/v1/collaborative/lists/\(listId)/items/\(itemId)",
            method: "PUT",
            body: body
        )
    }

    public func setCollaborativeItemPurchased(itemId: Int64, listId: Int64, userId: Int64, isPurchased: Bool) async throws {
        _ = userId
        try await requestNoContent(
            path: "/api/v1/collaborative/lists/\(listId)/items/\(itemId)/purchase",
            method: "PUT",
            body: ["isPurchased": isPurchased]
        )
    }

    public func setCollaborativeItemHidden(itemId: Int64, listId: Int64, userId: Int64, isHidden: Bool) async throws {
        _ = userId
        try await requestNoContent(
            path: "/api/v1/collaborative/lists/\(listId)/items/\(itemId)/hidden",
            method: "PUT",
            body: ["isHidden": isHidden]
        )
    }

    public func deleteCollaborativeItem(itemId: Int64, listId: Int64, userId: Int64) async throws {
        _ = userId
        try await requestNoContent(path: "/api/v1/collaborative/lists/\(listId)/items/\(itemId)", method: "DELETE")
    }

    private func request<Response: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: Any?]? = nil
    ) async throws -> Response {
        let (data, response) = try await performRequest(path: path, method: method, body: body)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func requestNoContent(
        path: String,
        method: String,
        body: [String: Any?]? = nil
    ) async throws {
        let (data, response) = try await performRequest(path: path, method: method, body: body)
        try validate(response: response, data: data)
    }

    private func performRequest(
        path: String,
        method: String,
        body: [String: Any?]? = nil
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: buildURL(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: compactJSONObject(body))
        }
        return try await session.data(for: request)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAPIError(message: "Invalid server response")
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            if let payload = try? JSONDecoder().decode(RemoteErrorBody.self, from: data) {
                throw RemoteAPIError(message: payload.error.message)
            }
            throw RemoteAPIError(message: "Request failed (\(httpResponse.statusCode))")
        }
    }

    private func buildURL(path: String) -> URL {
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            return absoluteURL
        }
        let trimmedBase = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: trimmedBase + normalizedPath)!
    }

    private func compactJSONObject(_ dictionary: [String: Any?]) -> [String: Any] {
        dictionary.compactMapValues { $0 }
    }

    /// Flattens `metadata`'s fields (via its own `Codable` conformance) into a plain
    /// dictionary suitable for merging into a request body — keeps the 15-field list
    /// defined exactly once instead of duplicated into every call site that sends it.
    private func metadataJSONFields(_ metadata: WishListItemMetadata) throws -> [String: Any] {
        let data = try JSONEncoder().encode(metadata)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func makeUser(from user: RemoteUser) async throws -> User {
        let imageData = await loadImageData(from: user.imageURL)
        return User(
            id: user.id,
            firstName: user.firstName,
            lastName: user.lastName,
            displayName: user.displayName,
            email: user.email,
            passwordHash: "",
            bio: user.bio,
            profileImageData: imageData
        )
    }

    /// Loads every item's image concurrently (each is a separate HTTP round-trip) rather
    /// than one at a time — a list of N items no longer takes N sequential round-trips.
    private func mapWishListItems(_ items: [RemoteItem], listId: Int64, userId: Int64) async -> [WishListItem] {
        await withTaskGroup(of: (Int, WishListItem).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    (index, await self.makeWishListItem(from: item, listId: listId, userId: userId))
                }
            }
            var results: [(Int, WishListItem)] = []
            results.reserveCapacity(items.count)
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func makeWishListItem(from item: RemoteItem, listId: Int64, userId: Int64) async -> WishListItem {
        let imageData = await loadCachedItemImageData(from: item.imageURL)
        return WishListItem(
            id: item.id,
            userId: userId,
            listId: listId,
            productName: item.productName,
            price: item.price,
            quantity: item.quantity,
            url: item.url,
            isPurchased: item.isPurchased,
            isHidden: item.isHidden,
            imageData: imageData,
            metadata: item.metadata
        )
    }

    private func mapCollaborativeItems(_ items: [RemoteItem], listId: Int64) async -> [CollaborativeItem] {
        await withTaskGroup(of: (Int, CollaborativeItem).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    (index, await self.makeCollaborativeItem(from: item, listId: listId))
                }
            }
            var results: [(Int, CollaborativeItem)] = []
            results.reserveCapacity(items.count)
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func makeCollaborativeItem(from item: RemoteItem, listId: Int64) async -> CollaborativeItem {
        let imageData = await loadCachedItemImageData(from: item.imageURL)
        return CollaborativeItem(
            id: item.id,
            listId: listId,
            productName: item.productName,
            price: item.price,
            quantity: item.quantity,
            url: item.url,
            isPurchased: item.isPurchased,
            isHidden: item.isHidden,
            imageData: imageData,
            metadata: item.metadata
        )
    }

    /// `WishListStore`/`CollaborativeStore` call `refreshItems()` after every mutation
    /// (add, edit, purchase-toggle, hide-toggle, delete), which re-fetches the whole
    /// list — including every unchanged item's image — every time. An item's image
    /// never changes after creation today (`WishListRepository.updateItem`'s SQL
    /// doesn't touch `image_data`, in either local or remote mode), so it's safe to
    /// fetch each item's image once per path and reuse it on every later refresh. If an
    /// "edit item photo" feature is ever added, this cache will need to be invalidated
    /// (or keyed by something that changes when the photo does) alongside that work.
    private var itemImageCache: [String: Data] = [:]

    private func loadCachedItemImageData(from path: String?) async -> Data? {
        guard let path else { return nil }
        if let cached = itemImageCache[path] {
            return cached
        }
        let data = await loadImageData(from: path)
        itemImageCache[path] = data
        return data
    }

    private func loadImageData(from path: String?) async -> Data? {
        guard let path else { return nil }
        var request = URLRequest(url: buildURL(path: path))
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}
