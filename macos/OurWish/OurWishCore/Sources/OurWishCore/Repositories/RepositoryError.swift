import Foundation

/// Errors surfaced by the repository layer, mirroring the validation the original
/// Express routes performed before touching the database.
public enum RepositoryError: LocalizedError, Equatable {
    case invalidCredentials
    case emailAlreadyExists
    case userLimitReached(max: Int)
    case wishListNotFound
    case cannotDeleteOnlyWishList
    case itemNotFound
    case collaborativeListNotFound
    case partnerNotFound
    case cannotCollaborateWithSelf
    case incorrectCurrentPassword
    case userNotFound
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .incorrectCurrentPassword:
            return "Current password is incorrect"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyExists:
            return "Email already exists"
        case .userLimitReached(let max):
            return "Maximum users (\(max)) already registered"
        case .wishListNotFound:
            return "Wish list not found"
        case .cannotDeleteOnlyWishList:
            return "Cannot delete your only wish list"
        case .itemNotFound:
            return "Item not found"
        case .collaborativeListNotFound:
            return "Collaborative list not found"
        case .partnerNotFound:
            return "Partner user not found"
        case .cannotCollaborateWithSelf:
            return "Cannot create a collaborative list with yourself"
        case .invalidInput(let message):
            return message
        }
    }
}
