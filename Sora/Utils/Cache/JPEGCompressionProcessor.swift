//
//  JPEGCompressionProcessor.swift
//  Sora
//
//  Created by Francesco on 02/06/25.
//


import Kingfisher
import UIKit

struct JPEGCompressionProcessor: ImageProcessor {
    let identifier: String
    let compressionQuality: CGFloat

    init(compressionQuality: CGFloat) {
        self.compressionQuality = compressionQuality
        self.identifier = "me.cranci.JPEGCompressionProcessor_\(compressionQuality)"
    }

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case .image(let image):
            guard let data = image.jpegData(compressionQuality: compressionQuality),
                  let compressedImage = UIImage(data: data) else {
                return image
            }
            return compressedImage
        case .data(let data):
            guard let image = UIImage(data: data) else { return nil }
            guard let compressedData = image.jpegData(compressionQuality: compressionQuality),
                  let compressedImage = UIImage(data: compressedData) else {
                return image
            }
            return compressedImage
        }
    }
}
