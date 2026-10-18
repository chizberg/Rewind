//
//  BottomSheet.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 10. 2026.
//

import SwiftUI
import VGSL

final class BottomSheet: UIViewController, UIGestureRecognizerDelegate {
  struct State: Equatable {
    enum Detent: CaseIterable {
      case minimized
      case normal
      case fullscreen
    }

    var visibleHeight: CGFloat
    var detent: Detent

    fileprivate var offset: CGFloat
  }

  @ObservableProperty
  private var state: State
  private let content: UIViewController
  private let sheetView = UIView()

  private let pan = UIPanGestureRecognizer()
  private let touchDown = UILongPressGestureRecognizer()

  init(content: (ObservableVariable<State>) -> UIViewController) {
    let state = ObservableProperty(initialValue: State(
      visibleHeight: 0,
      detent: .normal,
      offset: 0,
    ))
    _state = state
    self.content = content(state.projectedValue.skipRepeats())
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = PassthroughView(sheetView: sheetView)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(sheetView)

    addChild(content)
    content.view.frame = sheetView.bounds
    content.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    sheetView.addSubview(content.view)
    content.didMove(toParent: self)

    pan.addTarget(self, action: #selector(handlePan))
    pan.delegate = self
    view.addGestureRecognizer(pan)

    touchDown.addTarget(self, action: #selector(handleTouchDown))
    touchDown.minimumPressDuration = 0
    touchDown.cancelsTouchesInView = false
    touchDown.delegate = self
    view.addGestureRecognizer(touchDown)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let top = view.safeAreaInsets.top
    let size = CGSize(
      width: view.bounds.width,
      height: view.bounds.height - top
    )
    if sheetView.bounds.size != size {
      sheetView.bounds.size = size
      sheetView.center = CGPoint(x: size.width / 2, y: top + size.height / 2)
      move(to: state.detent)
    }
  }

  func setDetent(_ detent: State.Detent, animated: Bool) {
    guard touchDown.state != .began, touchDown.state != .changed else { return }
    if animated {
      settle(to: detent, velocity: 0)
    } else {
      move(to: detent)
    }
  }

  func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer,
  ) -> Bool {
    true
  }

  @objc
  private func handleTouchDown(_ recognizer: UILongPressGestureRecognizer) {
    switch recognizer.state {
    case .began:
      if let presentation = sheetView.layer.presentation() {
        apply(offset: presentation.affineTransform().ty, detent: state.detent)
      }
      sheetView.layer.removeAllAnimations()
    case .ended, .cancelled:
      if pan.state == .possible || pan.state == .failed {
        settle(to: state.detent, velocity: 0)
      }
    default:
      break
    }
  }

  @objc
  private func handlePan(_ recognizer: UIPanGestureRecognizer) {
    switch recognizer.state {
    case .began, .changed:
      let dragged = state.offset + recognizer.translation(in: view).y
      apply(offset: dragged.clamp(0...offset(for: .minimized)), detent: state.detent)
      recognizer.setTranslation(.zero, in: view)
    case .ended, .cancelled:
      let velocity = recognizer.velocity(in: view).y
      let current = nearestDetentIndex(to: state.offset)
      let projected = nearestDetentIndex(to: state.offset + project(velocity))
      settle(
        to: State.Detent.allCases[projected.clamp(current - 1...current + 1)],
        velocity: velocity,
      )
    default:
      break
    }
  }

  private func settle(to detent: State.Detent, velocity: CGFloat) {
    let distance = offset(for: detent) - state.offset
    UIView.animate(
      springDuration: 0.5,
      initialSpringVelocity: abs(distance) > 1 ? (velocity / distance).clamp(-30...30) : 0,
      options: .allowUserInteraction,
    ) { [self] in
      move(to: detent)
    }
  }

  private func move(to detent: State.Detent) {
    apply(offset: offset(for: detent), detent: detent)
  }

  private func apply(offset: CGFloat, detent: State.Detent) {
    sheetView.transform = CGAffineTransform(translationX: 0, y: offset)
    state = State(
      visibleHeight: sheetView.bounds.height - offset,
      detent: detent,
      offset: offset,
    )
  }

  private func offset(for detent: State.Detent) -> CGFloat {
    switch detent {
    case .minimized: sheetView.bounds.height - 58
    case .normal: sheetView.bounds.height - 235.5
    case .fullscreen: 0
    }
  }

  private func nearestDetentIndex(to offset: CGFloat) -> Int {
    let offsets = State.Detent.allCases.map(offset(for:))
    return offsets.indices.min { abs(offsets[$0] - offset) < abs(offsets[$1] - offset) } ?? 0
  }

  private func project(_ velocity: CGFloat) -> CGFloat {
    let rate = UIScrollView.DecelerationRate.normal.rawValue
    return velocity / 1000 * rate / (1 - rate)
  }
}

private final class PassthroughView: UIView {
  private let sheetView: UIView

  init(sheetView: UIView) {
    self.sheetView = sheetView
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
    (sheetView.layer.presentation()?.frame ?? sheetView.frame).contains(point)
  }
}

#if DEBUG
#Preview {
  @Previewable @State
  var detent = BottomSheet.State.Detent.normal

  ZStack(alignment: .top) {
    Color.blue.ignoresSafeArea()

    ViewControllerRepresentable {
      BottomSheet { _ in
        UIHostingController(rootView: ScrollView {
          LazyVStack {
            ForEach(0..<50) { i in
              Text("Row \(i)")
                .frame(maxWidth: .infinity, minHeight: 44)
            }
          }
        })
      }
    } updater: { vc in
      vc.setDetent(detent, animated: true)
    }
    .ignoresSafeArea()

    Picker("Detent", selection: $detent) {
      ForEach(BottomSheet.State.Detent.allCases, id: \.self) { detent in
        Text(String(describing: detent))
      }
    }
    .pickerStyle(.segmented)
    .padding()
  }
}
#endif
