import SwiftUI

struct AvatarView: View {
    let photoData: Data?
    let initials: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.plum
                    if initials.isEmpty {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.45))
                    } else {
                        Text(initials)
                            .font(Theme.Fonts.avatarInitials(size: size * 0.4))
                    }
                }
                .foregroundStyle(Theme.onPlum)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        AvatarView(photoData: nil, initials: "MF")
        AvatarView(photoData: nil, initials: "", size: 96)
    }
}
