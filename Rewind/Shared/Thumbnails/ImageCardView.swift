//
//  ImageCardView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 10. 2026.
//

import SwiftUI
import VGSL

struct ImageCardView: View {
  var image: Model.Image
  var backgroundColor: SwiftUI.Color

  @State
  private var titleStyle: ThumbnailTitleStyle?
  @Environment(\.sheetFullscreenProgress)
  private var sheetFullscreenProgress

  var body: some View {
    background
      .aspectRatio(3 / 4, contentMode: .fit)
      .overlay {
        imageView
      }
      .overlay(alignment: .topLeading) {
        let padding = radius - 10
        title
          .padding(padding)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background {
            VariableBlurView(gradient: .easedFade(), maxRadius: 20)
            LinearGradient(
              gradient: .easedFade(
                Color.black.opacity(
                  titleStyle?.dimming ?? 0
                )
              ),
              startPoint: .top,
              endPoint: .bottom
            )
          }
      }
      .overlay(alignment: .bottomLeading) {
        ImageDateView(date: image.date)
          .font(.footnote)
          .padding(radius - ImageDateView.cardRadius)
      }
      .clipShape(RoundedRectangle(cornerRadius: radius))
      .contentShape(Rectangle())
      .overlay {
        RoundedRectangle(cornerRadius: radius)
          .strokeBorder(.white.opacity(0.2), lineWidth: 1)
      }
  }

  @ViewBuilder
  private var background: some View {
    if let sheetFullscreenProgress {
      ViewRepresentable {
        SheetCardBackgroundView(fullscreenProgress: sheetFullscreenProgress)
      }
    } else {
      backgroundColor
    }
  }

  private var imageView: some View {
    RewindAsyncImage(image.image, .medium) { loaded in
      Image(uiImage: loaded)
        .resizable()
        .scaledToFill()
        // to hide the unreadable gray line at the bottom
        .scaleEffect(1.08, anchor: .top)
        .task(id: loaded) {
          let style = await ThumbnailTitleStyle.measure(
            loaded,
            widthToHeight: 3 / 4,
            captionFraction: 0.3,
          )
          withAnimation {
            titleStyle = style
          }
        }
    } placeholder: {
      SwiftUI.Color.clear.overlay {
        DelayedProgressView()
      }
    }
  }

  private var title: some View {
    Text(image.title)
      .multilineTextAlignment(.leading)
      .lineLimit(3)
      .font(.system(.body, design: .serif).bold())
      .foregroundStyle(titleStyle?.titleColor ?? .primary)
  }
}

private final class SheetCardBackgroundView: UIView {
  private let fillView = UIView()
  private let disposePool = AutodisposePool()

  init(fullscreenProgress: ObservableVariable<CGFloat>) {
    super.init(frame: .zero)
    backgroundColor = .mapControlBackground
    fillView.backgroundColor = .secondarySystemBackground
    fillView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(fillView)
    fullscreenProgress.currentAndNewValues.addObserver { [weak self] in
      self?.fillView.alpha = $0
    }.dispose(in: disposePool)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private let radius = 25.0

extension EnvironmentValues {
  @Entry
  var sheetFullscreenProgress: ObservableVariable<CGFloat>?
}

#if DEBUG
#Preview("panorama touch test") {
  ImageCardView(
    image: modified(.mock) {
      $0.image = .panorama
    },
    backgroundColor: SwiftUI.Color(uiColor: .secondarySystemBackground),
  )
  .frame(height: 300)
  .onTapGesture {
    debugLog("foo")
  }
}
#endif

extension UIColor {
  static let mapControlBackground = UIColor(dynamicProvider: { trait in
    switch trait.userInterfaceStyle {
    case .dark: .black.withAlphaComponent(0.3)
    case .light, .unspecified: fallthrough
    @unknown default: .white.withAlphaComponent(0.6)
    }
  })
}
