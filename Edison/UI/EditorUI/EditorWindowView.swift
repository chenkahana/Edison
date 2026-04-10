import AppKit
import SwiftUI

struct EditorWindowView: View {
    let imageData: Data?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Screenshot Editor")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    onClose()
                }
            }

            if let imageData,
               let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ContentUnavailableView("No Screenshot", systemImage: "photo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
}
