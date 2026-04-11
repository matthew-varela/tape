import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case athlete
    case recruiter
    case brand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .athlete: "Athlete"
        case .recruiter: "Coach"
        case .brand: "Brand"
        }
    }

    var description: String {
        switch self {
        case .athlete: "Upload highlights & build your recruiting profile"
        case .recruiter: "Discover and recruit top talent"
        case .brand: "Find athletes for NIL partnerships"
        }
    }

    var icon: String {
        switch self {
        case .athlete: "figure.run"
        case .recruiter: "sportscourt"
        case .brand: "building.2"
        }
    }
}

enum SubscriptionTier: String, Codable {
    case free
    case pro
}

struct User: Codable, Identifiable, Hashable {
    let id: String
    var email: String
    var displayName: String
    var role: UserRole
    var tier: SubscriptionTier
    var profileImageURL: String?

    // Athlete-specific
    var highSchool: String?
    var gradYear: Int?
    var sport: String?
    var position: String?
    var state: String?
    var height: String?
    var weight: String?
    var fortyYardDash: String?
    var gpa: Double?

    // Recruiter/Brand-specific
    var organization: String?
    var title: String?

    // Analytics
    var profileViewsThisWeek: Int
    var profileViewerIDs: [String]

    // Messaging
    var dmsSentThisMonth: Int

    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        role: UserRole,
        tier: SubscriptionTier = .free,
        profileImageURL: String? = nil,
        highSchool: String? = nil,
        gradYear: Int? = nil,
        sport: String? = nil,
        position: String? = nil,
        state: String? = nil,
        height: String? = nil,
        weight: String? = nil,
        fortyYardDash: String? = nil,
        gpa: Double? = nil,
        organization: String? = nil,
        title: String? = nil,
        profileViewsThisWeek: Int = 0,
        profileViewerIDs: [String] = [],
        dmsSentThisMonth: Int = 0
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.tier = tier
        self.profileImageURL = profileImageURL
        self.highSchool = highSchool
        self.gradYear = gradYear
        self.sport = sport
        self.position = position
        self.state = state
        self.height = height
        self.weight = weight
        self.fortyYardDash = fortyYardDash
        self.gpa = gpa
        self.organization = organization
        self.title = title
        self.profileViewsThisWeek = profileViewsThisWeek
        self.profileViewerIDs = profileViewerIDs
        self.dmsSentThisMonth = dmsSentThisMonth
    }

    var subtitle: String {
        switch role {
        case .athlete:
            let parts = [highSchool, gradYear.map { "'\(String($0).suffix(2))" }, position].compactMap { $0 }
            return parts.joined(separator: " | ")
        case .recruiter:
            return [title, organization].compactMap { $0 }.joined(separator: " at ")
        case .brand:
            return organization ?? ""
        }
    }
}
