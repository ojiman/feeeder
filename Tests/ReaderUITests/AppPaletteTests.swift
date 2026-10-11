import AppKit
import Testing
@testable import UnagiReader

@MainActor struct AppPaletteTests {
    private func rgb(_ color: NSColor, _ name: NSAppearance.Name) -> (r: CGFloat, g: CGFloat, b: CGFloat, saturation: CGFloat) {
        var result = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), saturation: CGFloat(0))
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
            let c = color.usingColorSpace(.sRGB)!
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            result = (c.redComponent, c.greenComponent, c.blueComponent, s)
        }
        return result
    }
    private func luminance(_ c: (r: CGFloat, g: CGFloat, b: CGFloat, saturation: CGFloat)) -> CGFloat {
        func f(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    private func contrast(_ a: CGFloat, _ b: CGFloat) -> CGFloat { (max(a, b) + 0.05) / (min(a, b) + 0.05) }

    @Test func theAccentIsSofterThanTheSystemOrangeAndStillReadable() {
        let dark = rgb(AppPalette.accent, .darkAqua), light = rgb(AppPalette.accent, .aqua)
        let system = rgb(.systemOrange, .darkAqua)
        #expect(dark.saturation < system.saturation - 0.2)                                      // clearly less loud than systemOrange (about 0.96)
        #expect(dark.saturation < 0.65 && light.saturation < 0.9)
        let darkBackground = luminance((r: 30 / 255, g: 30 / 255, b: 30 / 255, saturation: 0))
        #expect(contrast(luminance(dark), darkBackground) >= 7)                                 // a dot or a mark on the dark pane
        #expect(contrast(luminance(light), 1) >= 3.5)                                           // on white (marks, not body text)
    }
}
