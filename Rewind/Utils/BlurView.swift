//
//  BlurView.swift
//  CameraRoll
//
//  Created by Alexey Sherstnev on 22.03.2023.
//

import SwiftUI

struct BlurView: UIViewRepresentable {
  var style: UIBlurEffect.Style = .regular
  var animated: Bool = false
  var radius: CGFloat = 0

  func makeUIView(context _: Context) -> UIVisualEffectView {
    let effect = UIBlurEffect(style: style)
    let uiView = UIVisualEffectView(effect: effect)
    uiView.clipsToBounds = true
    return uiView
  }

  func updateUIView(_ uiView: UIVisualEffectView, context _: Context) {
    uiView.layer.cornerRadius = radius

    UIView.animate(withDuration: animated ? 0.5 : 0) {
      let effect = UIBlurEffect(style: style)
      uiView.effect = effect
    }
  }
}

struct BlurView_Previews: PreviewProvider {
  static var previews: some View {
    ZStack {
      Image("cat")
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

extension UIBlurEffect.Style: @retroactive CaseIterable {
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
    case .extraLight: "extraLight"
    case .light: "light"
    case .dark: "dark"
    case .regular: "regular"
    case .prominent: "prominent"
    case .systemUltraThinMaterial: "systemUltraThinMaterial"
    case .systemThinMaterial: "systemThinMaterial"
    case .systemMaterial: "systemMaterial"
    case .systemThickMaterial: "systemThickMaterial"
    case .systemChromeMaterial: "systemChromeMaterial"
    case .systemUltraThinMaterialLight: "systemUltraThinMaterialLight"
    case .systemThinMaterialLight: "systemThinMaterialLight"
    case .systemMaterialLight: "systemMaterialLight"
    case .systemThickMaterialLight: "systemThickMaterialLight"
    case .systemChromeMaterialLight: "systemChromeMaterialLight"
    case .systemUltraThinMaterialDark: "systemUltraThinMaterialDark"
    case .systemThinMaterialDark: "systemThinMaterialDark"
    case .systemMaterialDark: "systemMaterialDark"
    case .systemThickMaterialDark: "systemThickMaterialDark"
    case .systemChromeMaterialDark: "systemChromeMaterialDark"
    @unknown default: "unknown"
    }
  }
}
