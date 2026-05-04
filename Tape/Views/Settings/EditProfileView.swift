import PhotosUI
import SwiftUI
import Kingfisher

/// `EditProfileView` lets the signed-in user update their profile fields and
/// avatar. The save flow is:
///   1. (Optional) Upload the newly-picked avatar image to Firebase Storage,
///      get back a download URL.
///   2. PUT the merged `User` record to the backend.
///   3. Ask `AuthViewModel` to re-fetch `/api/users/me` so the updated record
///      propagates everywhere through the SwiftUI environment.
///
/// We construct an `APIProfileService` and `FirebaseStorageService` once per
/// view instance via `@State` — Swift will keep them alive for the view's
/// lifetime, and SwiftUI won't recreate them on every re-render.
struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    // Form state bound to the text fields.
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

    // Avatar state.
    @State private var profileImageURL: String?
    @State private var pickedImageItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    // Save flow state.
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let profileService: ProfileServiceProtocol = APIProfileService()
    private let storageService: StorageServiceProtocol = FirebaseStorageService()

    private var currentUser: User? {
        if case .authenticated(let user) = authVM.authState { return user }
        return nil
    }

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    avatarPicker
                    formField("Display Name", text: $displayName)
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
            // PhotosPickerItem holds a reference; we have to actually load the
            // image data on a background task before we can show or upload it.
            guard let newValue else { return }
            Task { await loadPickedImage(newValue) }
        }
    }

    // MARK: - Subviews

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickedImageItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                avatarImage
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.tapeRed, lineWidth: 3))

                Image(systemName: "pencil.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.tapeRed)
                    .background(Circle().fill(Color.tapeDarkBg))
            }
        }
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
            // 1. Upload the new avatar (if one was picked) and capture the URL.
            if let pickedImage {
                let url = try await storageService.uploadProfileImage(
                    image: pickedImage,
                    userID: user.id
                )
                user.profileImageURL = url.absoluteString
            }

            // 2. Apply the form values onto the User record.
            user.displayName = displayName
            user.highSchool = nilIfEmpty(highSchool)
            user.gradYear = Int(gradYear)
            user.sport = nilIfEmpty(sport)
            user.position = nilIfEmpty(position)
            user.state = nilIfEmpty(state)
            user.height = nilIfEmpty(height)
            user.weight = nilIfEmpty(weight)
            user.fortyYardDash = nilIfEmpty(fortyYardDash)
            user.gpa = Double(gpa)

            // 3. Persist to the backend.
            try await profileService.updateProfile(user)

            // 4. Refresh the env-wide auth user so every screen sees the change.
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
