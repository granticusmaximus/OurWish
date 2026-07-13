import Foundation
import Hummingbird
import OurWishCore

struct CreateWishListRequest: Codable {
    let name: String
}

/// Item request bodies hold `metadata` as a single `WishListItemMetadata`, decoded by
/// delegating to the same flat JSON object `WishListItemMetadata` already knows how to
/// read (see its `Decodable` conformance) — one field list to maintain instead of one
/// per request/response type, with no change to the wire format.
struct CreateItemRequest: Decodable {
    let productName: String
    let price: Double
    let quantity: Int
    let url: String?
    /// Base64-encoded photo the client already resolved (e.g. the native app's
    /// URL-based fetch preview). May be nil even when `clientResolvedImage` is true —
    /// that means the client looked and found nothing, or the user explicitly cleared
    /// it, and the server must not override that by auto-fetching from `url` itself.
    let imageBase64: String?
    /// True when the client already ran its own photo-resolution flow (the native app
    /// always does, via its URL-fetch preview). Older/simpler clients like the PWA omit
    /// this, so the server falls back to its own URL fetch as before.
    let clientResolvedImage: Bool?
    let metadata: WishListItemMetadata

    private enum CodingKeys: String, CodingKey {
        case productName, price, quantity, url, imageBase64, clientResolvedImage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = try container.decode(String.self, forKey: .productName)
        price = try container.decode(Double.self, forKey: .price)
        quantity = try container.decode(Int.self, forKey: .quantity)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
        clientResolvedImage = try container.decodeIfPresent(Bool.self, forKey: .clientResolvedImage)
        metadata = try WishListItemMetadata(from: decoder)
    }
}

struct UpdateItemRequest: Decodable {
    let productName: String
    let price: Double
    let quantity: Int
    let url: String?
    /// Same semantics as `CreateItemRequest.imageBase64`/`clientResolvedImage`: nil
    /// `imageBase64` with `clientResolvedImage == true` means the client explicitly
    /// cleared the photo, not "leave it alone." When `clientResolvedImage` is omitted
    /// (e.g. the PWA, which never resolves a photo client-side), the route handler
    /// preserves the item's existing photo unless `url` itself changed.
    let imageBase64: String?
    let clientResolvedImage: Bool?
    let metadata: WishListItemMetadata

    private enum CodingKeys: String, CodingKey {
        case productName, price, quantity, url, imageBase64, clientResolvedImage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = try container.decode(String.self, forKey: .productName)
        price = try container.decode(Double.self, forKey: .price)
        quantity = try container.decode(Int.self, forKey: .quantity)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
        clientResolvedImage = try container.decodeIfPresent(Bool.self, forKey: .clientResolvedImage)
        metadata = try WishListItemMetadata(from: decoder)
    }
}

struct SetPurchasedRequest: Codable {
    let isPurchased: Bool
}

struct SetHiddenRequest: Codable {
    let isHidden: Bool
}

/// Shared with `CollaborativeRoutes`, same as `SetPurchasedRequest`/`SetHiddenRequest`.
struct ReorderItemsRequest: Codable {
    let orderedItemIds: [Int64]
}

struct ItemsResponseDTO: Encodable, ResponseEncodable {
    let active: [ItemDTO]
    let purchased: [ItemDTO]
}

struct WishListRoutes {
    let repository: WishListRepository

    private func requireUserId(_ context: AppRequestContext) throws -> Int64 {
        guard let userId = context.userId else { throw HTTPError(.unauthorized) }
        return userId
    }

    func addRoutes(to group: RouterGroup<AppRequestContext>) {
        group.get("/wishlists") { _, context -> [WishListDTO] in
            let userId = try requireUserId(context)
            return try repository.lists(for: userId).map(WishListDTO.init)
        }

        group.post("/wishlists") { request, context -> WishListDTO in
            let userId = try requireUserId(context)
            let body = try await request.decode(as: CreateWishListRequest.self, context: context)
            do {
                return WishListDTO(try repository.createList(userId: userId, name: body.name))
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/wishlists/:id") { request, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            let body = try await request.decode(as: CreateWishListRequest.self, context: context)
            do {
                try repository.renameList(listId: listId, userId: userId, name: body.name)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.delete("/wishlists/:id") { _, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            do {
                try repository.deleteList(listId: listId, userId: userId)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.get("/wishlists/:id/items") { _, context -> ItemsResponseDTO in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            do {
                let active = try repository.items(listId: listId, userId: userId, purchased: false)
                let purchased = try repository.items(listId: listId, userId: userId, purchased: true)
                return ItemsResponseDTO(active: active.map(ItemDTO.init), purchased: purchased.map(ItemDTO.init))
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.post("/wishlists/:id/items") { request, context -> ItemDTO in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            let body = try await request.decode(as: CreateItemRequest.self, context: context)

            // Prefer a photo the client already resolved (including a deliberate "no
            // photo"). Only auto-fetch server-side (same LinkPresentation-backed
            // fetcher the native app uses) when the client didn't resolve one itself —
            // e.g. the PWA, which has no client-side fetch of its own.
            var imageData: Data?
            if body.clientResolvedImage == true {
                imageData = body.imageBase64.flatMap { base64 in
                    Data(base64Encoded: base64).flatMap {
                        ImageResizing.resizedJPEGData(from: $0, maxDimension: 512, compressionQuality: 0.8)
                    }
                }
            } else if let url = body.url, !url.isEmpty {
                imageData = await ProductImageFetcher.fetchImageData(for: url)
            }

            do {
                let item = try repository.addItem(
                    listId: listId, userId: userId, productName: body.productName,
                    price: body.price,
                    quantity: body.quantity,
                    url: body.url,
                    imageData: imageData,
                    metadata: body.metadata
                )
                return ItemDTO(item)
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/wishlists/:id/items/reorder") { request, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            let body = try await request.decode(as: ReorderItemsRequest.self, context: context)
            do {
                try repository.reorderItems(listId: listId, userId: userId, orderedItemIds: body.orderedItemIds)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/items/:id") { request, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let itemId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            let body = try await request.decode(as: UpdateItemRequest.self, context: context)

            guard let existingItem = try repository.item(id: itemId, userId: userId) else {
                throw RepositoryError.itemNotFound.httpError
            }

            // Prefer a photo the client already resolved (including a deliberate "no
            // photo"). Otherwise, only auto-fetch when the URL actually changed — a
            // routine metadata-only edit (the PWA's case, which never resolves a photo
            // client-side) must not silently wipe or re-fetch an unrelated photo.
            var imageData: Data?
            if body.clientResolvedImage == true {
                imageData = body.imageBase64.flatMap { base64 in
                    Data(base64Encoded: base64).flatMap {
                        ImageResizing.resizedJPEGData(from: $0, maxDimension: 512, compressionQuality: 0.8)
                    }
                }
            } else if let url = body.url, !url.isEmpty, url != existingItem.url {
                imageData = await ProductImageFetcher.fetchImageData(for: url) ?? existingItem.imageData
            } else {
                imageData = existingItem.imageData
            }

            do {
                try repository.updateItem(
                    itemId: itemId, userId: userId, productName: body.productName,
                    price: body.price,
                    quantity: body.quantity,
                    url: body.url,
                    imageData: imageData,
                    metadata: body.metadata
                )
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/items/:id/purchase") { request, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let itemId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            let body = try await request.decode(as: SetPurchasedRequest.self, context: context)
            do {
                try repository.setPurchased(itemId: itemId, userId: userId, isPurchased: body.isPurchased)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/items/:id/hidden") { request, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let itemId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            let body = try await request.decode(as: SetHiddenRequest.self, context: context)
            do {
                try repository.setHidden(itemId: itemId, userId: userId, isHidden: body.isHidden)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.delete("/items/:id") { _, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let itemId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            do {
                try repository.deleteItem(itemId: itemId, userId: userId)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }
    }

    /// Mounted separately at `/api/v1/items` (this is what `ItemDTO.imageURL` points at
    /// for personal items).
    func addImageRoute(to group: RouterGroup<AppRequestContext>) {
        group.get("/:id/image") { _, context -> Response in
            let userId = try requireUserId(context)
            guard let itemId = context.parameters.get("id", as: Int64.self),
                  let item = try repository.item(id: itemId, userId: userId),
                  let imageData = item.imageData else {
                throw HTTPError(.notFound)
            }
            return Response(
                status: .ok,
                headers: [.contentType: "image/jpeg"],
                body: .init(byteBuffer: ByteBuffer(data: imageData))
            )
        }
    }
}
