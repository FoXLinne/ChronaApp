import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appModel: AppViewModel
    @State private var showAboutSheet = false
    @State private var showProfileEditor = false
    @State private var draftProfile = ProfileInfo.default
    private let profileLeadingWidth: CGFloat = 60

    private var displayName: String {
        let trimmed = appModel.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Chrona" : trimmed
    }

    private var displaySignature: String {
        let trimmed = appModel.profile.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "profile.signature") : trimmed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        draftProfile = appModel.profile
                        showProfileEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            AvatarSymbolView(imageData: appModel.profile.avatarImageData, size: 58)
                                .frame(width: profileLeadingWidth, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(displaySignature)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .tint(.primary)
                    NavigationLink {
                        DailyCheckInView()
                    } label: {
                        HStack(spacing: 12) {
                            CheckInLeadingCluster(hasCheckedInToday: appModel.hasCheckedInToday)
                                .frame(width: profileLeadingWidth, alignment: .leading)

                            Text(String(localized: "checkin.title"))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(
                                String(
                                    format: String(localized: "checkin.streak.days"),
                                    appModel.checkInStreak
                                )
                            )
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 0)
                    }
                    .tint(.primary)
                }

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text(String(localized: "profile.settings"))
                    }

                    Button(String(localized: "profile.about")) {
                        showAboutSheet = true
                    }
                }
            }
            .scrollContentBackground(colorScheme == .light ? .hidden : .automatic)
            .chronaSoftScrollEdgeEffect()
            .background {
                if colorScheme == .light {
                    PageBackground(seed: "sunset")
                }
            }
            .navigationTitle(String(localized: "tab.profile"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showAboutSheet) {
                NavigationStack {
                    AboutView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditorView(profile: $draftProfile) {
                    showProfileEditor = false
                } onSave: {
                    appModel.profile = draftProfile
                    showProfileEditor = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct CheckInLeadingCluster: View {
    let hasCheckedInToday: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            Circle()
                .fill(hasCheckedInToday ? Color.green : Color.accentColor)
                .frame(width: 16, height: 16)
                .overlay {
                    Image(systemName: hasCheckedInToday ? "checkmark" : "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 2, y: 2)
        }
        .frame(height: 30)
    }
}

private struct AvatarSymbolView: View {
    let imageData: Data?
    let size: CGFloat

    private var avatarImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))

            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ProfileEditorView: View {
    @Binding var profile: ProfileInfo
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var cropSourceImage: UIImage?
    @State private var showAvatarCropper = false
    @State private var showPhotoSelector = false
    @State private var showFileImporter = false
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 24) {
            avatarSection

            inputFields

            buttonSection

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .photosPicker(isPresented: $showPhotoSelector, selection: $selectedPhotoItem, matching: .images)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result,
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    cropSourceImage = image
                    showAvatarCropper = true
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                cropSourceImage = image
                showAvatarCropper = true
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showAvatarCropper) {
            if let cropSourceImage {
                NavigationStack {
                    AvatarCropperView(image: cropSourceImage) {
                        showAvatarCropper = false
                    } onConfirm: { croppedImage in
                        profile.avatarImageData = processedAvatarData(from: croppedImage)
                        showAvatarCropper = false
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard
                    let rawData = try? await newItem.loadTransferable(type: Data.self),
                    let pickedImage = UIImage(data: rawData)
                else { return }
                await MainActor.run {
                    cropSourceImage = pickedImage
                    showAvatarCropper = true
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                AvatarSymbolView(imageData: profile.avatarImageData, size: 100)

                Menu {
                    if profile.avatarImageData != nil {
                        Button(role: .destructive) {
                            profile.avatarImageData = nil
                        } label: {
                            Label(String(localized: "profile.avatar.photo.remove"), systemImage: "trash")
                        }
                    }
                    Button {
                        showFileImporter = true
                    } label: {
                        Label(String(localized: "profile.avatar.photo.file"), systemImage: "folder")
                    }
                    Button {
                        showCamera = true
                    } label: {
                        Label(String(localized: "profile.avatar.photo.camera"), systemImage: "camera")
                    }
                    Button {
                        showPhotoSelector = true
                    } label: {
                        Label(String(localized: "profile.avatar.photo.pick"), systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }
                .offset(x: 4, y: 4)
            }
        }
    }

    private var inputFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "profile.name"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("", text: $profile.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "profile.signature"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("", text: $profile.signature, axis: .vertical)
                    .lineLimit(2...3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
            }
        }
    }

    private var buttonSection: some View {
        VStack(spacing: 12) {
            Button {
                onSave()
            } label: {
                Text(String(localized: "profile.save"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.label))
                    )
            }

            Button {
                onCancel()
            } label: {
                Text(String(localized: "common.cancel"))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func processedAvatarData(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 512
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > maxSide else {
            return image.jpegData(compressionQuality: 0.85)
        }
        let scale = maxSide / largestSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

private struct AvatarCropperView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let cropSide = max(220, min(proxy.size.width - 32, proxy.size.height - 220))
            let baseScale = max(cropSide / image.size.width, cropSide / image.size.height)
            let normalizedZoom = min(max(zoom, 1), 4)
            let displaySize = CGSize(
                width: image.size.width * baseScale * normalizedZoom,
                height: image.size.height * baseScale * normalizedZoom
            )

            ZStack {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer(minLength: 12)

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: displaySize.width, height: displaySize.height)
                            .offset(offset)
                    }
                    .frame(width: cropSide, height: cropSide)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                let proposed = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = clampedOffset(
                                    proposed,
                                    cropSide: cropSide,
                                    displaySize: displaySize
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let nextZoom = min(max(lastZoom * value, 1), 4)
                                zoom = nextZoom

                                let nextDisplaySize = CGSize(
                                    width: image.size.width * baseScale * nextZoom,
                                    height: image.size.height * baseScale * nextZoom
                                )
                                offset = clampedOffset(
                                    offset,
                                    cropSide: cropSide,
                                    displaySize: nextDisplaySize
                                )
                            }
                            .onEnded { value in
                                let nextZoom = min(max(lastZoom * value, 1), 4)
                                zoom = nextZoom
                                lastZoom = nextZoom

                                let nextDisplaySize = CGSize(
                                    width: image.size.width * baseScale * nextZoom,
                                    height: image.size.height * baseScale * nextZoom
                                )
                                offset = clampedOffset(
                                    offset,
                                    cropSide: cropSide,
                                    displaySize: nextDisplaySize
                                )
                                lastOffset = offset
                            }
                    )

                    Text(String(localized: "profile.avatar.crop.hint"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))

                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle(String(localized: "profile.avatar.crop"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.92), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        let normalized = normalizedImage(image)
                        guard
                            let cropped = croppedImage(
                                from: normalized,
                                cropSide: cropSide,
                                baseScale: baseScale,
                                zoom: normalizedZoom,
                                offset: offset
                            )
                        else {
                            onCancel()
                            return
                        }
                        onConfirm(cropped)
                    }
                }
            }
        }
    }

    private func clampedOffset(_ proposed: CGSize, cropSide: CGFloat, displaySize: CGSize) -> CGSize {
        let maxX = max(0, (displaySize.width - cropSide) * 0.5)
        let maxY = max(0, (displaySize.height - cropSide) * 0.5)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func croppedImage(
        from source: UIImage,
        cropSide: CGFloat,
        baseScale: CGFloat,
        zoom: CGFloat,
        offset: CGSize
    ) -> UIImage? {
        guard let cgImage = source.cgImage else { return nil }

        let displayWidth = source.size.width * baseScale * zoom
        let displayHeight = source.size.height * baseScale * zoom

        let imageOriginX = (cropSide - displayWidth) * 0.5 + offset.width
        let imageOriginY = (cropSide - displayHeight) * 0.5 + offset.height

        let cropRectInPoints = CGRect(
            x: (0 - imageOriginX) * source.size.width / displayWidth,
            y: (0 - imageOriginY) * source.size.height / displayHeight,
            width: cropSide * source.size.width / displayWidth,
            height: cropSide * source.size.height / displayHeight
        )

        let pxRatioX = CGFloat(cgImage.width) / source.size.width
        let pxRatioY = CGFloat(cgImage.height) / source.size.height

        var cropRectInPixels = CGRect(
            x: cropRectInPoints.origin.x * pxRatioX,
            y: cropRectInPoints.origin.y * pxRatioY,
            width: cropRectInPoints.size.width * pxRatioX,
            height: cropRectInPoints.size.height * pxRatioY
        ).integral

        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        cropRectInPixels = cropRectInPixels.intersection(imageBounds)

        guard
            cropRectInPixels.width > 0,
            cropRectInPixels.height > 0,
            let croppedCGImage = cgImage.cropping(to: cropRectInPixels)
        else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: 1, orientation: .up)
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

private struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ProfileView()
    .environmentObject(AppViewModel.previewModel())
}
