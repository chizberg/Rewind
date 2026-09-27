//
//  FullscreenPreview.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23.2.25.
//

import SwiftUI
import UIKit

struct FullscreenPreview: View {
  var store: FullscreenPreviewStore

  @State
  private var zoomValue: CGFloat = 1
  @State
  private var controlsHidden = false

  var body: some View {
    ZStack(alignment: .top) {
      Color.black
        .ignoresSafeArea()

      ZoomableImageView(
        image: store.image,
        zoomValue: $zoomValue,
        onTap: { withAnimation { controlsHidden.toggle() } },
      )
      .ignoresSafeArea()
      .onChange(of: zoomValue) { old, new in
        if old == 1, new > 1 {
          withAnimation { controlsHidden = true }
        } else if old != 1, new == 1 {
          withAnimation { controlsHidden = false }
        }
      }

      SavedBanner(savesCount: store.savesCount)
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(action: { store(.saveImage) }, label: {
          Image(
            systemName: store.savesCount > 0
              ? "square.and.arrow.down.badge.checkmark"
              : "square.and.arrow.down",
          )
        })
      }
    }
    .toolbarVisibility(controlsHidden ? .hidden : .visible, for: .navigationBar)
    .alert(store.binding(\.alert, send: { _ in .dismissAlert }))
  }
}

struct ZoomableImageView: View {
  var image: UIImage
  @Binding
  var zoomValue: CGFloat
  var onTap: () -> Void

  var body: some View {
    ViewRepresentable {
      let view = ZoomableImageViewImpl(
        zoomValue: $zoomValue,
        onTap: onTap,
      )
      view.set(image: image)
      return view
    }
  }
}

#if DEBUG
#Preview {
  NavigationStack {
    FullscreenPreview(
      store: makeFullscreenPreviewStore(
        image: UIImage(named: "cat")!,
        savesCount: 0,
        saveImage: {},
        source: .mock,
      ),
    )
  }
}
#endif

private final class ZoomableImageViewImpl: UIScrollView, UIScrollViewDelegate {
  private let imageView: UIImageView
  private var previousFrameSize: CGSize = .zero
  private let zoomValue: Binding<CGFloat>
  private let onTap: () -> Void

  init(
    zoomValue: Binding<CGFloat> = .constant(1),
    onTap: @escaping () -> Void,
  ) {
    imageView = UIImageView()
    self.zoomValue = zoomValue
    self.onTap = onTap
    super.init(frame: .zero)
    addSubview(imageView)

    delegate = self
    contentInsetAdjustmentBehavior = .never
    showsVerticalScrollIndicator = false
    showsHorizontalScrollIndicator = false
    minimumZoomScale = 1

    let doubleTap = TapActionRecognizer { [weak self] in
      self?.doubleTap()
    }
    doubleTap.numberOfTapsRequired = 2
    addGestureRecognizer(doubleTap)

    let tap = TapActionRecognizer(action: onTap)
    tap.require(toFail: doubleTap)
    addGestureRecognizer(tap)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func set(image: UIImage) {
    imageView.image = image
    updateLayout(image: image)
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // layoutSubviews is called while zooming
    // we should ignore it
    if previousFrameSize != frame.size,
       let image = imageView.image {
      zoomScale = 1
      updateLayout(image: image)
      previousFrameSize = frame.size
    }
  }

  private func doubleTap() {
    if zoomScale == 1 {
      setZoomScale(maximumZoomScale, animated: true)
    } else {
      setZoomScale(1, animated: true)
    }
  }

  private func updateLayout(image: UIImage) {
    let imageViewSize = calculateImageViewSize(image: image)
    imageView.frame = CGRect(origin: .zero, size: imageViewSize)
    contentSize = imageViewSize

    updateInsets()

    maximumZoomScale = calculateMaxScale(image: image)
  }

  private func calculateMaxScale(image: UIImage) -> CGFloat {
    let widthScale = image.size.width / frame.width
    let heightScale = image.size.height / frame.height
    let contentScale = max(widthScale, heightScale)
    // if content is smaller than screen, should still be zoomable
    return max(contentScale, 1.2)
  }

  private func calculateImageViewSize(image: UIImage) -> CGSize {
    let aspectRatio = image.size.width / image.size.height
    let frameRatio = frame.width / frame.height

    if frameRatio > aspectRatio {
      let height = frame.height
      let width = height * aspectRatio
      return CGSize(width: width, height: height)
    } else {
      let width = frame.width
      let height = width / aspectRatio
      return CGSize(width: width, height: height)
    }
  }

  private func updateInsets() {
    let offsetX = max((frame.width - contentSize.width) / 2, 0)
    let offsetY = max((frame.height - contentSize.height) / 2, 0)
    contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
  }

  // UIScrollViewDelegate
  func viewForZooming(in _: UIScrollView) -> UIView? {
    imageView
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    zoomValue.wrappedValue = scrollView.zoomScale
    updateInsets()
  }
}

private final class TapActionRecognizer: UITapGestureRecognizer {
  let action: () -> Void

  init(action: @escaping () -> Void) {
    self.action = action
    super.init(target: nil, action: nil)
    addTarget(self, action: #selector(handleTap))
  }

  @objc
  private func handleTap() {
    action()
  }
}
