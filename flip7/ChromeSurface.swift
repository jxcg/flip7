import SwiftUI

/// The one availability shim in the app.
///
/// Floating chrome gets glass on iOS 26 and the same geometry in
/// `.regularMaterial` with a hairline below it. The layout is identical in
/// both; only the material differs. Thirteen scattered availability checks is
/// how a design language dies.
///
/// Cards and the table never get this. Glass cannot sample glass, and a card
/// that borrows colour from whatever is behind it destroys the value ramp's
/// whole purpose.
struct ChromeSurface: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      content.background(.bar)
    } else {
      content
        .background(.regularMaterial)
        .overlay(alignment: .top) {
          Rectangle()
            .fill(Color(.separator))
            .frame(height: 1 / UIScreen.main.scale)
        }
    }
  }
}

extension View {
  /// Marks a surface that floats above the table.
  func chromeSurface() -> some View {
    modifier(ChromeSurface())
  }
}
