//
//  UIImage+Color.swift
//  RangeSeekSliderDemo
//
//  Created by M Ivaniushchenko on 11.11.2019.
//

import UIKit

extension UIImage {
    static func image(color: UIColor, size: CGSize, roundingCorners: UIRectCorner, cornerRadius: CGFloat, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        defer { UIGraphicsEndImageContext() }
            
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.setFillColor(color.cgColor)
        
        let bezierPath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size),
                                      byRoundingCorners: roundingCorners,
                                      cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        bezierPath.fill()
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    static func image(color: UIColor) -> UIImage? {
        let size = CGFloat(32)
        let radius = size/2
        
        let image = self.image(color: color,
                               size: CGSize(width: size, height: size),
                               roundingCorners: .allCorners,
                               cornerRadius: radius)
        
        return image?.resizableImage(withCapInsets: UIEdgeInsets(top: radius, left: radius, bottom: radius, right: radius))
    }
}
