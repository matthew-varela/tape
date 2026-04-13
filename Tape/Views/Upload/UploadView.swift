import PhotosUI
import SwiftUI

struct UploadView: View {
    let currentUser: User
    @State private var uploadVM = UploadViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showTrimmer = false
    @State private var showTagSelection = false
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                if currentUser.role != .athlete {
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("Upload is for Athletes")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Only athletes can upload highlight clips.\nUse Search or the Feed to discover talent.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    if uploadVM.selectedVideoURL == nil {
                        pickerPrompt
                    } else if uploadVM.needsTrimming && !showTagSelection {
                        VideoTrimmerView(uploadVM: uploadVM) {
                            showTagSelection = true
                        }
                    } else {
                        TagSelectionView(uploadVM: uploadVM) {
                            Task {
                                await uploadVM.publish(currentUser: currentUser)
                                if uploadVM.isPublished {
                                    showSuccessAlert = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if uploadVM.selectedVideoURL != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            uploadVM.reset()
                            showTagSelection = false
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: VideoTransferable.self) {
                        await uploadVM.processSelectedVideo(url: data.url)
                        if !uploadVM.needsTrimming {
                            showTagSelection = true
                        }
                    }
                }
            }
            .alert("Highlight Published!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    uploadVM.isPublished = false
                    selectedItem = nil
                }
            } message: {
                Text("Your clip is now live on the feed.")
            }
        }
    }

    private var pickerPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "film.stack.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.tapeRed)

            Text("Add Your Highlight")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Upload a 5-15 second clip.\nLonger videos will be trimmed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PhotosPicker(
                selection: $selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                Label("Choose Video", systemImage: "photo.on.rectangle.angled")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.tapeRed)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
