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
    var fullscreenProgress: CGFloat

    fileprivate var offset: CGFloat
  }

  @ObservableProperty
  private var state: State
  private let content: UIViewController
  private let sheetView = UIView()

  private let pan = UIPanGestureRecognizer()
  private let touchDown = UILongPressGestureRecognizer()
  private weak var scrollView: UIScrollView?
  private var contentOffsetObservation: NSKeyValueObservation?
  private let disposePool = AutodisposePool()

  private var lockedScrolledDistance: CGFloat?
  private var pendingDetent: State.Detent?

  init(
    detent: ObservableVariable<State.Detent>,
    height: CGFloat,
    content: (ObservableVariable<State>) -> UIViewController,
  ) {
    let state = ObservableProperty(initialValue: State(
      sheetHeight: height,
      offset: detent.value.offset(sheetHeight: height),
      detent: detent.value,
    ))
    _state = state
    self.content = content(state.projectedValue.skipRepeats())
    super.init(nibName: nil, bundle: nil)
    detent.newValues.delay(0).addObserver { [weak self] in
      self?.set(detent: $0, animated: true)
    }.dispose(in: disposePool)
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
    if sheetView.bounds.size != view.bounds.size {
      sheetView.bounds.size = view.bounds.size
      sheetView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
      move(to: state.detent)
    }
  }

  func set(detent: State.Detent, animated: Bool) {
    guard detent != state.detent else { return }
    guard touchDown.state != .began, touchDown.state != .changed else {
      pendingDetent = detent
      return
    }
    if animated {
      settle(to: detent, velocity: 0)
    } else {
      move(to: detent)
    }
  }

  func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer,
  ) -> Bool {
    if scrollView == nil,
       let scrollView = other.view as? UIScrollView,
       other === scrollView.panGestureRecognizer,
       scrollView.isVerticallyScrollable || scrollView.alwaysBounceVertical {
      track(scrollView: scrollView)
    }
    return true
  }

  func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
    if recognizer === pan {
      let translation = pan.translation(in: view)
      return abs(translation.y).isApproximatelyGreaterOrEqualThan(abs(translation.x))
    }
    return true
  }

  @objc
  private func handleTouchDown(recognizer: UILongPressGestureRecognizer) {
    switch recognizer.state {
    case .began:
      if let presentation = sheetView.layer.presentation() {
        apply(offset: presentation.affineTransform().ty, detent: state.detent)
      }
      sheetView.layer.removeAllAnimations()
      lockedScrolledDistance = nil
    case .ended, .cancelled:
      if pan.state == .possible || pan.state == .failed {
        settle(to: pendingDetent ?? state.detent, velocity: 0)
      }
    default:
      break
    }
  }

  @objc
  private func handlePan(recognizer: UIPanGestureRecognizer) {
    switch recognizer.state {
    case .began, .changed:
      let translation = recognizer.translation(in: view).y
      recognizer.setTranslation(.zero, in: view)
      guard shouldMoveSheet(translation: translation) else {
        lockedScrolledDistance = nil
        return
      }
      lockContentOffset()
      let draggedOffset = state.offset + translation
      apply(
        offset: draggedOffset.clamp(offset(for: .fullscreen)...offset(for: .minimized)),
        detent: state.detent,
      )
    case .ended, .cancelled:
      let velocity = recognizer.velocity(in: view).y
      let detent = pendingDetent
        ?? (scrollView != nil && isSheetAtTop ? .fullscreen : detent(releasedWith: velocity))
      settle(to: detent, velocity: velocity)
    default:
      break
    }
  }

  private func shouldMoveSheet(translation: CGFloat) -> Bool {
    guard let scrollView, scrollView.isTracking, isSheetAtTop else { return true }
    let isContentAtTop = scrollView.contentOffset.y
      .isApproximatelyLessOrEqualThan(-scrollView.adjustedContentInset.top)
    return translation.isApproximatelyGreaterThan(0) && isContentAtTop
  }

  private func track(scrollView: UIScrollView) {
    self.scrollView = scrollView
    contentOffsetObservation = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
      MainActor.assumeIsolated {
        guard let lockedDistance = self?.lockedScrolledDistance else { return }
        let lockedY = lockedDistance - scrollView.adjustedContentInset.top
        guard scrollView.contentOffset.y.isApproximatelyNotEqualTo(
          lockedY,
          withAccuracy: 1 / scrollView.traitCollection.displayScale,
        ) else { return }
        scrollView.contentOffset.y = lockedY
      }
    }
  }

  private func lockContentOffset() {
    guard let scrollView, lockedScrolledDistance == nil else { return }
    let distance = max(scrollView.contentOffset.y + scrollView.adjustedContentInset.top, 0)
    lockedScrolledDistance = distance
    scrollView.contentOffset.y = distance - scrollView.adjustedContentInset.top
  }

  private func settle(to detent: State.Detent, velocity: CGFloat) {
    pendingDetent = nil
    let distance = offset(for: detent) - state.offset
    UIView.animate(
      springDuration: 0.5,
      initialSpringVelocity: abs(distance) > 1 ? (velocity / distance).clamp(-30...30) : 0,
      options: .allowUserInteraction,
    ) { [self] in
      move(to: detent)
    } completion: { [self] finished in
      guard finished, lockedScrolledDistance != nil, let scrollView else { return }
      scrollView.setContentOffset(scrollView.contentOffset, animated: false)
      lockedScrolledDistance = nil
    }
  }

  private func move(to detent: State.Detent) {
    apply(offset: offset(for: detent), detent: detent)
  }

  private func apply(offset: CGFloat, detent: State.Detent) {
    sheetView.transform = CGAffineTransform(translationX: 0, y: offset)
    state = State(sheetHeight: sheetView.bounds.height, offset: offset, detent: detent)
  }

  private func offset(for detent: State.Detent) -> CGFloat {
    detent.offset(sheetHeight: sheetView.bounds.height)
  }

  private func detent(releasedWith velocity: CGFloat) -> State.Detent {
    let detents = State.Detent.allCases
    if velocity > 500 {
      return detents.last { offset(for: $0) > state.offset } ?? .minimized
    }
    if velocity < -500 {
      return detents.first { offset(for: $0) < state.offset } ?? .fullscreen
    }
    return detents.min {
      abs(offset(for: $0) - state.offset) < abs(offset(for: $1) - state.offset)
    } ?? state.detent
  }

  private var isSheetAtTop: Bool {
    state.offset.isApproximatelyEqualTo(offset(for: .fullscreen))
  }
}

extension BottomSheet.State {
  fileprivate init(sheetHeight: CGFloat, offset: CGFloat, detent: Detent) {
    let normalOffset = Detent.normal.offset(sheetHeight: sheetHeight)
    self.init(
      visibleHeight: sheetHeight - offset,
      detent: detent,
      fullscreenProgress: (1 - offset / normalOffset).clamp(0...1),
      offset: offset,
    )
  }
}

extension BottomSheet.State.Detent {
  fileprivate func offset(sheetHeight: CGFloat) -> CGFloat {
    switch self {
    case .minimized: sheetHeight - 58
    case .normal: sheetHeight - 235.5
    case .fullscreen: 0
    }
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

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let modelY = sheetView.transform.ty
    let presentedY = sheetView.layer.presentation()?.affineTransform().ty ?? modelY
    let pointInModelSpace = CGPoint(x: point.x, y: point.y + modelY - presentedY)
    return sheetView.hitTest(convert(pointInModelSpace, to: sheetView), with: event)
  }
}

#if DEBUG
#Preview {
  @Previewable @State
  var detent = BottomSheet.State.Detent.normal

  ZStack(alignment: .top) {
    Color.blue.ignoresSafeArea()

    GeometryReader { geometry in
      ViewControllerRepresentable {
        BottomSheet(detent: .constant(.normal), height: geometry.size.height) { _ in
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
        vc.set(detent: detent, animated: true)
      }
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
