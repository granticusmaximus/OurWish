import Foundation
import Hummingbird
import OurWishCore

struct CreateCollaborativeListRequest: Codable {
    let partnerEmail: String
    let name: String
}

struct CollaborativeRoutes {
    let repository: CollaborativeListRepository
    let userRepository: UserRepository

    private func requireUserId(_ context: AppRequestContext) throws -> Int64 {
        guard let userId = context.userId else { throw HTTPError(.unauthorized) }
        return userId
    }

    func addRoutes(to group: RouterGroup<AppRequestContext>) {
        group.get("/collaborative/partners") { _, context -> [PartnerDTO] in
            let userId = try requireUserId(context)
            return try userRepository.partners(excluding: userId).map(PartnerDTO.init)
        }

        group.get("/collaborative/lists") { _, context -> [CollaborativeListDTO] in
            let userId = try requireUserId(context)
            return try repository.lists(for: userId).map(CollaborativeListDTO.init)
        }

        group.post("/collaborative/lists") { request, context -> CollaborativeListDTO in
            let userId = try requireUserId(context)
            let body = try await request.decode(as: CreateCollaborativeListRequest.self, context: context)
            do {
                let list = try repository.createList(
                    currentUserId: userId, partnerEmail: body.partnerEmail, name: body.name
                )
                let lists = try repository.lists(for: userId)
                guard let created = lists.first(where: { $0.id == list.id }) else {
                    throw HTTPError(.internalServerError)
                }
                return CollaborativeListDTO(created)
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.delete("/collaborative/lists/:listId") { _, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("listId", as: Int64.self) else { throw HTTPError(.badRequest) }
            do {
                try repository.deleteList(listId: listId, userId: userId)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.get("/collaborative/lists/:listId/items") { _, context -> ItemsResponseDTO in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("listId", as: Int64.self) else { throw HTTPError(.badRequest) }
            do {
                let active = try repository.items(listId: listId, userId: userId, purchased: false)
                let purchased = try repository.items(listId: listId, userId: userId, purchased: true)
                return ItemsResponseDTO(active: active.map(ItemDTO.init), purchased: purchased.map(ItemDTO.init))
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.post("/collaborative/lists/:listId/items") { request, context -> ItemDTO in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("listId", as: Int64.self) else { throw HTTPError(.badRequest) }
            let body = try await request.decode(as: CreateItemRequest.self, context: context)

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

        group.put("/collaborative/lists/:listId/items/:itemId") { request, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("listId", as: Int64.self),
                  let itemId = context.parameters.get("itemId", as: Int64.self) else {
                throw HTTPError(.badRequest)
            }
            let body = try await request.decode(as: UpdateItemRequest.self, context: context)
            do {
                try repository.updateItem(
                    itemId: itemId, listId: listId, userId: userId, productName: body.productName,
                    price: body.price, quantity: body.quantity, url: body.url
                )
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/collaborative/lists/:listId/items/:itemId/purchase") { request, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("listId", as: Int64.self),
                  let itemId = context.parameters.get("itemId", as: Int64.self) else {
                throw HTTPError(.badRequest)
            }
            let body = try await request.decode(as: SetPurchasedRequest.self, context: context)
            do {
                try repository.setPurchased(itemId: itemId, listId: listId, userId: userId, isPurchased: body.isPurchased)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.delete("/collaborative/lists/:listId/items/:itemId") { _, context -> HTTPResponse.Status in
            let userId = try requireUserId(context)
            guard let listId = context.parameters.get("listId", as: Int64.self),
                  let itemId = context.parameters.get("itemId", as: Int64.self) else {
                throw HTTPError(.badRequest)
            }
            do {
                try repository.deleteItem(itemId: itemId, listId: listId, userId: userId)
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }
    }

    /// Mounted separately at `/api/v1/collaborative-items` (this is what
    /// `ItemDTO.imageURL` points at for collaborative items).
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
