//
//  QRCodeGenerator.swift
//  Mercury
//
//  Created by Nico Ameghino on 24/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation
import CoreImage
import UIKit
import CoreGraphics

func generate(from text: String) -> UIImage {
    let data = text.data(using: String.Encoding.isoLatin1, allowLossyConversion: false)
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { fatalError("could not build filter") }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("Q", forKey: "inputCorrectionLevel")
    let transform = CGAffineTransform(scaleX: 5, y: 5)
    guard
        let output = filter.outputImage?.transformed(by: transform)
    else { fatalError("could not get output image") }
    return UIImage(ciImage: output)
}
