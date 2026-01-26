import Foundation

final class OpenRCT2TickCoordinator {
    enum Owner {
        case engineQueue
        case displayLink
    }

    static let shared = OpenRCT2TickCoordinator()
    private let lock = NSLock()
    private var owner: Owner?

    func acquire(_ newOwner: Owner) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if owner == nil || owner == newOwner {
            owner = newOwner
            return true
        }
        return false
    }

    func release(_ existingOwner: Owner) {
        lock.lock()
        defer { lock.unlock() }
        if owner == existingOwner {
            owner = nil
        }
    }
}
