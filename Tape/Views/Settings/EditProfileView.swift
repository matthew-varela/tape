import PhotosUI
import SwiftUI
import Kingfisher

/// Lets the signed-in user update their avatar and profile fields.
///
/// Athletes get vitals + a top-schools shortlist. Coaches/brands set their
/// school, team affiliation (derived from the school), and coaching position.
/// Every role can set a profile picture.
///
/// Save flow:
///   1. (Optional) Upload a newly-picked avatar to Firebase Storage.
///   2. PUT the merged `User` record to the backend.
///   3. Refresh `/api/users/me` so the change propagates through the env.
struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var highSchool = ""
    @State private var gradYear = ""
    @State private var sport = ""
    @State private var position = ""
    @State private var state = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var fortyYardDash = ""
    @State private var gpa = ""
    /// Coaching role at the program — "Head Coach", "Recruiting Coordinator".
    @State private var coachPosition = ""

    @State private var targetSchoolIDs: [String] = []
    /// Single-id list for the coach's school so it shares `SchoolPickerView`.
    @State private var coachSchoolIDs: [String] = []
    @State private var showSchoolPicker = false
    private let maxTargetSchools = 5

    @State private var profileImageURL: String?
    @State private var pickedImageItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let profileService: ProfileServiceProtocol = APIProfileService()
    private let storageService: StorageServiceProtocol = FirebaseStorageService()

    private var currentUser: User? {
        if case .authenticated(let user) = authVM.authState { return user }
        return nil
    }

    private var isAthlete: Bool { currentUser?.role == .athlete }

    private var coachSchool: School? {
        SchoolCatalog.school(id: coachSchoolIDs.first)
    }

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    avatarPicker
                    formField("Display Name", text: $displayName)

                    if isAthlete {
                        athleteFields
                    } else {
                        coachBrandFields
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    saveButton
                }
                .padding(20)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: loadFromUser)
        .onChange(of: pickedImageItem) { _, newValue in
            guard let newValue else { return }
            Task { await loadPickedImage(newValue) }
        }
        .sheet(isPresented: $showSchoolPicker) {
            if isAthlete {
                SchoolPickerView(
                    title: "Top Schools",
                    maxSelection: maxTargetSchools,
                    selection: $targetSchoolIDs
                )
            } else {
                SchoolPickerView(
                    title: "Your School",
                    maxSelection: 1,
                    selection: $coachSchoolIDs
                )
            }
        }
    }

    // MARK: - Role-specific fields

    @ViewBuilder
    private var athleteFields: some View {
        formField("High School", text: $highSchool)
        formField("Graduation Year", text: $gradYear)
            .keyboardType(.numberPad)
        formField("Sport", text: $sport)
        formField("Position", text: $position)
        formField("State", text: $state)
        formField("Height (e.g. 6'2\")", text: $height)
        formField("Weight (lbs)", text: $weight)
            .keyboardType(.numberPad)
        formField("40-Yard Dash (s)", text: $fortyYardDash)
            .keyboardType(.decimalPad)
        formField("GPA", text: $gpa)
            .keyboardType(.decimalPad)
        topSchoolsField
    }

    @ViewBuilder
    private var coachBrandFields: some View {
        coachSchoolField

        if let school = coachSchool {
            // Team is derived from the school catalog — no free-text needed.
            VStack(alignment: .leading, spacing: 6) {
                Text("Team")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    SchoolLogo(school: school, size: 28)
                    Text(school.mascot)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }

        formField("Position (e.g. Head Coach)", text: $coachPosition)
    }

    private var coachSchoolField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("School")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showSchoolPicker = true
            } label: {
                HStack(spacing: 10) {
                    if let school = coachSchool {
                        SchoolLogo(school: school, size: 30)
                        Text(school.name)
                            .foregroundStyle(.white)
                    } else {
                        Text("Select your school")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var topSchoolsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Schools")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showSchoolPicker = true
            } label: {
                HStack(spacing: 10) {
                    if targetSchoolIDs.isEmpty {
                        Text("Pick up to \(maxTargetSchools) programs")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: -8) {
                            ForEach(SchoolCatalog.schools(ids: targetSchoolIDs)) { school in
                                SchoolLogo(school: school, size: 30)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Shared subviews

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickedImageItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                avatarImage
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.tapeRed, lineWidth: 3))

                Image(systemName: "camera.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.tapeRed)
                    .background(Circle().fill(Color.tapeDarkBg))
            }
        }
        .accessibilityLabel("Change profile photo")
        .padding(.top, 8)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let pickedImage {
            Image(uiImage: pickedImage)
                .resizable()
                .scaledToFill()
        } else if let urlString = profileImageURL, let url = URL(string: urlString) {
            KFImage(url)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    private var saveButton: some View {
        Button(action: { Task { await save() } }) {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save Changes").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.tapeRed)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isSaving)
    }

    private func formField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Behavior

    private func loadFromUser() {
        guard let user = currentUser else { return }
        displayName = user.displayName
        highSchool = user.highSchool ?? ""
        gradYear = user.gradYear.map(String.init) ?? ""
        sport = user.sport ?? ""
        position = user.position ?? ""
        state = user.state ?? ""
        height = user.height ?? ""
        weight = user.weight ?? ""
        fortyYardDash = user.fortyYardDash ?? ""
        gpa = user.gpa.map { String(format: "%.1f", $0) } ?? ""
        coachPosition = user.title ?? ""
        targetSchoolIDs = user.targetSchoolIDs
        coachSchoolIDs = [user.schoolId].compactMap { $0 }
        profileImageURL = user.profileImageURL
    }

    private func loadPickedImage(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { pickedImage = image }
            }
        } catch {
            await MainActor.run { errorMessage = "Couldn't load image: \(error.localizedDescription)" }
        }
    }

    private func save() async {
        guard var user = currentUser else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            if let pickedImage {
                let url = try await storageService.uploadProfileImage(
                    image: pickedImage,
                    userID: user.id
                )
                user.profileImageURL = url.absoluteString
            }

            user.displayName = displayName
            if isAthlete {
                user.highSchool = nilIfEmpty(highSchool)
                user.gradYear = Int(gradYear)
                user.sport = nilIfEmpty(sport)
                user.position = nilIfEmpty(position)
                user.state = nilIfEmpty(state)
                user.height = nilIfEmpty(height)
                user.weight = nilIfEmpty(weight)
                user.fortyYardDash = nilIfEmpty(fortyYardDash)
                user.gpa = Double(gpa)
                user.targetSchoolIDs = targetSchoolIDs
            } else {
                // Persist schoolId even when cleared — empty string tells the
                // backend to wipe the affiliation; null would leave it alone.
                let schoolID = coachSchoolIDs.first
                user.schoolId = schoolID ?? ""
                user.title = nilIfEmpty(coachPosition) ?? ""
                user.organization = SchoolCatalog.school(id: schoolID)?.name ?? ""
            }

            try await profileService.updateProfile(user)
            await authVM.refreshCurrentUser()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func nilIfEmpty(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
