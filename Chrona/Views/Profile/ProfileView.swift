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
            .background {
                if colorScheme == .light {
                    PageBackground(seed: "sunset")
                }
            }
            .navigationTitle(String(localized: "tab.profile"))
            .sheet(isPresented: $showAboutSheet) {
                NavigationStack {
                    AboutView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showProfileEditor) {
                NavigationStack {
                    ProfileEditorView(profile: $draftProfile) {
                        showProfileEditor = false
                    } onSave: {
                        appModel.profile = draftProfile
                        showProfileEditor = false
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
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

    private var previewName: String {
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Chrona" : trimmed
    }

    private var previewSignature: String {
        let trimmed = profile.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "profile.signature") : trimmed
    }

    var body: some View {
        Form {
            Section(String(localized: "profile.preview")) {
                HStack(spacing: 16) {
                    AvatarSymbolView(imageData: profile.avatarImageData, size: 84)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(previewName)
                            .font(.title3.weight(.semibold))

                        Text(previewSignature)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }

            Section(String(localized: "profile.user")) {
                TextField(String(localized: "profile.name"), text: $profile.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)

                TextField(String(localized: "profile.signature"), text: $profile.signature, axis: .vertical)
                    .lineLimit(2...3)
            }

            Section(String(localized: "profile.avatar")) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text(String(localized: "profile.avatar.photo.pick"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(.accentColor)

                if profile.avatarImageData != nil {
                    Button(role: .destructive) {
                        profile.avatarImageData = nil
                    } label: {
                        Text(String(localized: "profile.avatar.photo.remove"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "common.edit"))
        .navigationBarTitleDisplayMode(.inline)
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
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onSave()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(.accentColor)
            }
        }
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
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
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
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(.accentColor)
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

#Preview {
    ProfileView()
    .environmentObject(AppViewModel.previewModel())
}
