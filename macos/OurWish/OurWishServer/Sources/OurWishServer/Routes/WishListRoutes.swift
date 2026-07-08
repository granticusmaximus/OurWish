import Foundation
import Hummingbird
import OurWishCore

struct CreateWishListRequest: Codable {
    let name: String
}

struct CreateItemRequest: Codable {
    let productName: String
    let price: Double
    let quantity: Int
    let url: String?
}

struct UpdateItemRequest: Codable {
    let productName: String
    let price: Double
    let quantity: Int
    let url: String?
}

struct SetPurchasedRequest: Codable {
    let isPurchased: Bool
}

struct SetHiddenRequest: Codable {
    let isHidden: Bool
}

struct ItemsResponseDTO: Codable, ResponseEncodable {
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

            // Auto-fetch a product photo server-side (same LinkPresentation-backed
            // fetcher the native app uses) so the PWA doesn't need to implement its own.
            var imageData: Data?
            if let url = body.url, !url.isEmpty {
                imageData = await ProductImageFetcher.fetchImageData(for: url)
            }

            do {
                let item = try repository.addItem(
                    listId: listId, userId: userId, productName: body.productName,
                    price: body.price, quantity: body.quantity, url: body.url, imageData: imageData
                )
                return ItemDTO(item)
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/items/:id") { request, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let itemId = context.parameters.get("id", as: Int64.self) else { throw HTTPError(.badRequest) }
            let body = try await request.decode(as: UpdateItemRequest.self, context: context)
            do {
                try repository.updateItem(
                    itemId: itemId, userId: userId, productName: body.productName,
                    price: body.price, quantity: body.quantity, url: body.url
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
