//
//  BottomSheet.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 10. 2026.
//

import SwiftUI
import VGSL

final class BottomSheet: UIViewController {
  struct State: Equatable {
    enum Detent: CaseIterable {
      case minimized
      case normal
      case fullscreen
    }

    var visibleHeight: CGFloat
    var detent: Detent
  }

  @ObservableProperty
  private var state: State
  private let content: UIViewController
  private let sheetView = UIView()

  init(content: (ObservableVariable<State>) -> UIViewController) {
    let state = ObservableProperty(initialValue: State(
      visibleHeight: 0,
      detent: .normal,
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
    UIView.animate(
      springDuration: animated ? 0.5 : 0,
      options: .allowUserInteraction,
    ) { [self] in
      move(to: detent)
    }
  }

  private func move(to detent: State.Detent) {
    let offset = offset(for: detent)
    sheetView.transform = CGAffineTransform(translationX: 0, y: offset)
    state = State(
      visibleHeight: sheetView.bounds.height - offset,
      detent: detent,
    )
  }

  private func offset(for detent: State.Detent) -> CGFloat {
    switch detent {
    case .minimized: sheetView.bounds.height - minimizedHeight
    case .normal: sheetView.bounds.height - normalHeight
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

  override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
    sheetView.frame.contains(point)
  }
}

private let minimizedHeight: CGFloat = 58
private let normalHeight: CGFloat = 235.5

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
