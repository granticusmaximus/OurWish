import Foundation
import Hummingbird
import OurWishCore

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let password: String
}

struct UpdateProfileRequest: Codable {
    let firstName: String
    let lastName: String
    let displayName: String
    let bio: String?
    /// Base64-encoded image bytes. The client resends whatever photo it currently has
    /// loaded (including unchanged), and omits/nils this to remove the photo — there's
    /// no separate "leave photo alone" signal, so the client is responsible for
    /// round-tripping the existing photo when the user only edited other fields.
    let imageBase64: String?
}

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
}

struct AuthRoutes {
    let userRepository: UserRepository
    let tokenStore: TokenStore

    func addPublicRoutes(to group: RouterGroup<AppRequestContext>) {
        group.post("/login") { request, context -> LoginResponseDTO in
            let body = try await request.decode(as: LoginRequest.self, context: context)
            do {
                let user = try userRepository.login(email: body.email, password: body.password)
                let token = try await tokenStore.issueToken(for: user.id!)
                return LoginResponseDTO(token: token, user: UserDTO(user))
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }
    }

    func addProtectedRoutes(to group: RouterGroup<AppRequestContext>) {
        group.get("/user-count") { _, _ -> UserCountDTO in
            do {
                return UserCountDTO(count: try userRepository.count())
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.get("/me") { _, context -> UserDTO in
            guard let userId = context.userId, let user = try userRepository.user(id: userId) else {
                throw HTTPError(.unauthorized)
            }
            return UserDTO(user)
        }

        // Requires an existing session — mirrors the original Express app's
        // `req.session.userId` check for registration, which the native-only app had
        // relaxed to a UI-only rule. That's no longer safe once this endpoint is
        // reachable by anything on the LAN.
        group.post("/register") { request, context -> UserDTO in
            let body = try await request.decode(as: RegisterRequest.self, context: context)
            do {
                let user = try userRepository.createUser(
                    firstName: body.firstName, lastName: body.lastName,
                    email: body.email, password: body.password
                )
                return UserDTO(user)
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/profile") { request, context -> UserDTO in
            guard let userId = context.userId else { throw HTTPError(.unauthorized) }
            let body = try await request.decode(as: UpdateProfileRequest.self, context: context)

            let imageData: Data? = body.imageBase64.flatMap { base64 in
                Data(base64Encoded: base64).flatMap {
                    ImageResizing.resizedJPEGData(from: $0, maxDimension: 256, compressionQuality: 0.85)
                }
            }

            do {
                let user = try userRepository.updateProfile(
                    userId: userId, firstName: body.firstName, lastName: body.lastName,
                    displayName: body.displayName, bio: body.bio, profileImageData: imageData
                )
                return UserDTO(user)
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.put("/password") { request, context -> HTTPResponse.Status in
            guard let userId = context.userId else { throw HTTPError(.unauthorized) }
            let body = try await request.decode(as: ChangePasswordRequest.self, context: context)
            do {
                try userRepository.updatePassword(
                    userId: userId, currentPassword: body.currentPassword, newPassword: body.newPassword
                )
                return .noContent
            } catch let error as RepositoryError {
                throw error.httpError
            }
        }

        group.post("/logout") { _, context -> HTTPResponse.Status in
            guard let authToken = context.authToken else { throw HTTPError(.unauthorized) }
            try await tokenStore.revoke(authToken)
            return .noContent
        }

    }

    /// Mounted separately at `/api/v1/users`, outside the `/api/v1/auth` prefix (this
    /// is what `UserDTO.imageURL` points at).
    func addUserImageRoute(to group: RouterGroup<AppRequestContext>) {
        group.get("/:id/image") { _, context -> Response in
            guard let userIdString = context.parameters.get("id"), let userId = Int64(userIdString),
                  let user = try userRepository.user(id: userId),
                  let imageData = user.profileImageData else {
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
