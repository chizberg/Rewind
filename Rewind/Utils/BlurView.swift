//
//  BlurView.swift
//  CameraRoll
//
//  Created by Alexey Sherstnev on 22.03.2023.
//

import SwiftUI

struct BlurView: UIViewRepresentable {
  var style: UIBlurEffect.Style?
  var animated: Bool = false
  var radius: CGFloat = 0

  func makeUIView(context _: Context) -> UIVisualEffectView {
    let effect = style.flatMap(UIBlurEffect.init(style:))
    let uiView = UIVisualEffectView(effect: effect)
    uiView.clipsToBounds = true
    return uiView
  }

  func updateUIView(_ uiView: UIVisualEffectView, context _: Context) {
    uiView.layer.cornerRadius = radius

    UIView.animate(withDuration: animated ? 0.5 : 0) {
      let effect = style.flatMap(UIBlurEffect.init(style:))
      uiView.effect = effect
    }
  }
}

struct BlurView_Previews: PreviewProvider {
  static var previews: some View {
    ZStack {
      Image("imageMock")
        .resizable()
        .ignoresSafeArea()

      ScrollView(.vertical) {
        VStack {
          ForEach(UIBlurEffect.Style.allCases, id: \.rawValue) { style in
            BlurView(style: style)
              .frame(height: 200)
              .cornerRadius(10)
              .padding(20)
              .overlay {
                Text(style.name)
              }
          }
        }
      }
    }
  }
}

extension UIBlurEffect.Style: CaseIterable {
  public static var allCases: [UIBlurEffect.Style] = [
    .extraLight,
    .light,
    .dark,
    .regular,
    .prominent,
    .systemUltraThinMaterial,
    .systemThinMaterial,
    .systemMaterial,
    .systemThickMaterial,
    .systemChromeMaterial,
    .systemUltraThinMaterialLight,
    .systemThinMaterialLight,
    .systemMaterialLight,
    .systemThickMaterialLight,
    .systemChromeMaterialLight,
    .systemUltraThinMaterialDark,
    .systemThinMaterialDark,
    .systemMaterialDark,
    .systemThickMaterialDark,
    .systemChromeMaterialDark,
  ]

  fileprivate var name: String {
    switch self {
    case .extraLight: return "extraLight"
    case .light: return "light"
    case .dark: return "dark"
    case .regular: return "regular"
    case .prominent: return "prominent"
    case .systemUltraThinMaterial: return "systemUltraThinMaterial"
    case .systemThinMaterial: return "systemThinMaterial"
    case .systemMaterial: return "systemMaterial"
    case .systemThickMaterial: return "systemThickMaterial"
    case .systemChromeMaterial: return "systemChromeMaterial"
    case .systemUltraThinMaterialLight: return "systemUltraThinMaterialLight"
    case .systemThinMaterialLight: return "systemThinMaterialLight"
    case .systemMaterialLight: return "systemMaterialLight"
    case .systemThickMaterialLight: return "systemThickMaterialLight"
    case .systemChromeMaterialLight: return "systemChromeMaterialLight"
    case .systemUltraThinMaterialDark: return "systemUltraThinMaterialDark"
    case .systemThinMaterialDark: return "systemThinMaterialDark"
    case .systemMaterialDark: return "systemMaterialDark"
    case .systemThickMaterialDark: return "systemThickMaterialDark"
    case .systemChromeMaterialDark: return "systemChromeMaterialDark"
    @unknown default: return "unknown"
    }
  }
}
