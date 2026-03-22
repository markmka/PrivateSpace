import SwiftUI

struct SecretFieldView: View {
    let name: String
    @Binding var value: String
    @Binding var isRevealed: Bool
    let isSecret: Bool
    var onCopy: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isSecret && !isRevealed {
                    Text(String(repeating: "•", count: 12))
                        .font(.body)
                } else {
                    Text(value)
                        .font(.body)
                }
            }

            Spacer()

            if isSecret {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRevealed.toggle()
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }

            if let onCopy = onCopy {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
