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

private struct RemoteItem: Decodable {
    let id: Int64
    let productName: String
    let category: String?
    let manufacturer: String?
    let price: Double
    let msrp: Double?
    let quantity: Int
    let url: String?
    let officialProductURL: String?
    let bestRetailerURL: String?
    let primaryImageURL: String?
    let itemDescription: String?
    let specifications: String?
    let weight: String?
    let caliber: String?
    let compatibility: String?
    let purpose: String?
    let notes: String?
    let availabilityStatus: String?
    let dateRetrieved: String?
    let isPurchased: Bool
    let isHidden: Bool
    let imageURL: String?
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
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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
        _ = imageData
        let response: RemoteItem = try await request(
            path: "/api/v1/wishlists/\(listId)/items",
            method: "POST",
            body: [
                "productName": productName,
                "category": metadata.category,
                "manufacturer": metadata.manufacturer,
                "price": price,
                "msrp": metadata.msrp,
                "quantity": quantity,
                "url": url,
                "officialProductURL": metadata.officialProductURL,
                "bestRetailerURL": metadata.bestRetailerURL,
                "primaryImageURL": metadata.primaryImageURL,
                "itemDescription": metadata.itemDescription,
                "specifications": metadata.specifications,
                "weight": metadata.weight,
                "caliber": metadata.caliber,
                "compatibility": metadata.compatibility,
                "purpose": metadata.purpose,
                "notes": metadata.notes,
                "availabilityStatus": metadata.availabilityStatus,
                "dateRetrieved": metadata.dateRetrieved.map { Self.dateOnlyFormatter.string(from: $0) },
            ]
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
        try await requestNoContent(
            path: "/api/v1/items/\(itemId)",
            method: "PUT",
            body: [
                "productName": productName,
                "category": metadata.category,
                "manufacturer": metadata.manufacturer,
                "price": price,
                "msrp": metadata.msrp,
                "quantity": quantity,
                "url": url,
                "officialProductURL": metadata.officialProductURL,
                "bestRetailerURL": metadata.bestRetailerURL,
                "primaryImageURL": metadata.primaryImageURL,
                "itemDescription": metadata.itemDescription,
                "specifications": metadata.specifications,
                "weight": metadata.weight,
                "caliber": metadata.caliber,
                "compatibility": metadata.compatibility,
                "purpose": metadata.purpose,
                "notes": metadata.notes,
                "availabilityStatus": metadata.availabilityStatus,
                "dateRetrieved": metadata.dateRetrieved.map { Self.dateOnlyFormatter.string(from: $0) },
            ]
        )
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
        imageData: Data?
    ) async throws -> CollaborativeItem {
        _ = userId
        _ = imageData
        let response: RemoteItem = try await request(
            path: "/api/v1/collaborative/lists/\(listId)/items",
            method: "POST",
            body: ["productName": productName, "price": price, "quantity": quantity, "url": url]
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
        url: String?
    ) async throws {
        _ = userId
        try await requestNoContent(
            path: "/api/v1/collaborative/lists/\(listId)/items/\(itemId)",
            method: "PUT",
            body: ["productName": productName, "price": price, "quantity": quantity, "url": url]
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

    private func mapWishListItems(_ items: [RemoteItem], listId: Int64, userId: Int64) async -> [WishListItem] {
        var mapped: [WishListItem] = []
        for item in items {
            mapped.append(await makeWishListItem(from: item, listId: listId, userId: userId))
        }
        return mapped
    }

    private func makeWishListItem(from item: RemoteItem, listId: Int64, userId: Int64) async -> WishListItem {
        let imageData = await loadImageData(from: item.imageURL)
        let parsedDateRetrieved = item.dateRetrieved.flatMap {
            Self.dateOnlyFormatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0)
        }
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
            metadata: WishListItemMetadata(
                category: item.category,
                manufacturer: item.manufacturer,
                msrp: item.msrp,
                officialProductURL: item.officialProductURL,
                bestRetailerURL: item.bestRetailerURL,
                primaryImageURL: item.primaryImageURL,
                itemDescription: item.itemDescription,
                specifications: item.specifications,
                weight: item.weight,
                caliber: item.caliber,
                compatibility: item.compatibility,
                purpose: item.purpose,
                notes: item.notes,
                availabilityStatus: item.availabilityStatus,
                dateRetrieved: parsedDateRetrieved
            )
        )
    }

    private func mapCollaborativeItems(_ items: [RemoteItem], listId: Int64) async -> [CollaborativeItem] {
        var mapped: [CollaborativeItem] = []
        for item in items {
            mapped.append(await makeCollaborativeItem(from: item, listId: listId))
        }
        return mapped
    }

    private func makeCollaborativeItem(from item: RemoteItem, listId: Int64) async -> CollaborativeItem {
        let imageData = await loadImageData(from: item.imageURL)
        return CollaborativeItem(
            id: item.id,
            listId: listId,
            productName: item.productName,
            price: item.price,
            quantity: item.quantity,
            url: item.url,
            isPurchased: item.isPurchased,
            imageData: imageData
        )
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
