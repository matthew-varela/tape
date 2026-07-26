import Foundation

/// `UserRole` is the three-way axis the whole product divides users along.
/// The role determines which tabs are shown, what actions are gated, and how
/// the backend filters search results.
///
/// `Codable` with custom decoders below: the backend uses uppercased role
/// strings (`"ATHLETE"`) but our raw values are lowercase, so we accept either.
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

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let value = UserRole(rawValue: raw) {
            self = value
        } else if let value = UserRole(rawValue: raw.lowercased()) {
            self = value
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown UserRole: \(raw)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue.uppercased())
    }
}

/// Subscription tier. `.pro` unlocks the gated features (advanced filters,
/// unlimited DMs, profile viewer list, pinning, etc).
///
/// The source of truth at runtime is StoreKit 2 (`SubscriptionManager`); the
/// backend mirror stored on the User record is what `User.tier` reflects so
/// that other clients (e.g. recipient devices reading message metadata) can
/// render Pro-only badges without doing their own purchase lookup.
enum SubscriptionTier: String, Codable {
    case free
    case pro

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let value = SubscriptionTier(rawValue: raw) {
            self = value
        } else if let value = SubscriptionTier(rawValue: raw.lowercased()) {
            self = value
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown SubscriptionTier: \(raw)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue.uppercased())
    }
}

/// `User` is the canonical record of an account. The shape is intentionally
/// wide — we'd rather one model with optional fields per role than three
/// near-duplicates. Athlete fields (`gradYear`, `position`, etc.) are nil on
/// recruiter/brand records and vice versa.
///
/// Custom `init(from:)` decoder uses `decodeIfPresent` for nearly every key
/// so older servers that omit a field don't crash the client. Defaults are
/// chosen to match the in-app "empty" state.
struct User: Codable, Identifiable, Hashable {
    let id: String
    var email: String
    var displayName: String
    var role: UserRole
    var tier: SubscriptionTier
    var profileImageURL: String?

    // Age gating (ISO yyyy-MM-dd). `isMinor` is derived server-side.
    var dateOfBirth: String?
    var isMinor: Bool

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

    // Analytics (frontend-only convenience; backend may overwrite on /me).
    var profileViewsThisWeek: Int
    var profileViewerIDs: [String]

    // Messaging gating counter (per calendar month, server-managed).
    var dmsSentThisMonth: Int

    enum CodingKeys: String, CodingKey {
        case id, email, displayName, role, tier
        case dateOfBirth
        case isMinor = "minor"
        case profileImageURL = "profileImageUrl"
        case highSchool, gradYear, sport, position, state
        case height, weight, fortyYardDash, gpa
        case organization, title
        case profileViewsThisWeek, profileViewerIDs
        case dmsSentThisMonth
    }

    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        role: UserRole,
        tier: SubscriptionTier = .free,
        dateOfBirth: String? = nil,
        isMinor: Bool = false,
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
        self.dateOfBirth = dateOfBirth
        self.isMinor = isMinor
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        displayName = try c.decode(String.self, forKey: .displayName)
        role = try c.decode(UserRole.self, forKey: .role)
        tier = try c.decodeIfPresent(SubscriptionTier.self, forKey: .tier) ?? .free
        dateOfBirth = try c.decodeIfPresent(String.self, forKey: .dateOfBirth)
        isMinor = try c.decodeIfPresent(Bool.self, forKey: .isMinor) ?? false
        profileImageURL = try c.decodeIfPresent(String.self, forKey: .profileImageURL)
        highSchool = try c.decodeIfPresent(String.self, forKey: .highSchool)
        gradYear = try c.decodeIfPresent(Int.self, forKey: .gradYear)
        sport = try c.decodeIfPresent(String.self, forKey: .sport)
        position = try c.decodeIfPresent(String.self, forKey: .position)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        height = try c.decodeIfPresent(String.self, forKey: .height)
        weight = try c.decodeIfPresent(String.self, forKey: .weight)
        fortyYardDash = try c.decodeIfPresent(String.self, forKey: .fortyYardDash)
        gpa = try c.decodeIfPresent(Double.self, forKey: .gpa)
        organization = try c.decodeIfPresent(String.self, forKey: .organization)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        profileViewsThisWeek = try c.decodeIfPresent(Int.self, forKey: .profileViewsThisWeek) ?? 0
        profileViewerIDs = try c.decodeIfPresent([String].self, forKey: .profileViewerIDs) ?? []
        dmsSentThisMonth = try c.decodeIfPresent(Int.self, forKey: .dmsSentThisMonth) ?? 0
    }

    /// Concatenated subtitle shown beneath the display name in profile cards.
    /// Athletes get `HS | '26 | QB`, recruiters get `Title at Org`, etc.
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
