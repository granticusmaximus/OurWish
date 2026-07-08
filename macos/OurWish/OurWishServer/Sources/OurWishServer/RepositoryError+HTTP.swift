import Hummingbird
import OurWishCore

extension RepositoryError {
    var httpError: HTTPError {
        switch self {
        case .invalidCredentials, .incorrectCurrentPassword:
            return HTTPError(.unauthorized, message: errorDescription ?? "Unauthorized")
        case .emailAlreadyExists, .userLimitReached, .cannotDeleteOnlyWishList, .cannotCollaborateWithSelf, .invalidInput:
            return HTTPError(.badRequest, message: errorDescription ?? "Bad request")
        case .wishListNotFound, .itemNotFound, .collaborativeListNotFound, .partnerNotFound, .userNotFound:
            return HTTPError(.notFound, message: errorDescription ?? "Not found")
        }
    }
}
