import UIKit

/// Reduz uma fotografia à miniatura que efetivamente guardamos no
/// histórico (`Refeicao.thumbnailData`) — nunca a foto original.
enum ImageThumbnailer {

    static let maxDimension: CGFloat = 200

    static func makeThumbnail(from imageData: Data, compressionQuality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        return resize(image, maxDimension: maxDimension).jpegData(compressionQuality: compressionQuality)
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        guard scale < 1 else { return image }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()

        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
