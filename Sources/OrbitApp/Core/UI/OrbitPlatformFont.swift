import Foundation

#if os(macOS)
import AppKit

typealias OrbitPlatformFont = NSFont
typealias OrbitPlatformFontDescriptorDesign = NSFontDescriptor.SystemDesign
typealias OrbitPlatformFontWeight = NSFont.Weight
typealias OrbitPlatformTextStyle = NSFont.TextStyle
#elseif os(iOS)
import UIKit

typealias OrbitPlatformFont = UIFont
typealias OrbitPlatformFontDescriptorDesign = UIFontDescriptor.SystemDesign
typealias OrbitPlatformFontWeight = UIFont.Weight
typealias OrbitPlatformTextStyle = UIFont.TextStyle
#endif
