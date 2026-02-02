//
//  AlertPresenter.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 11. 11. 2025.
//

import SwiftUI
import VGSL

struct AlertParams {
  struct AlertAction {
    var title: LocalizedStringResource
    var style: UIAlertAction.Style = .default
    var handler: Action?
  }

  var title: LocalizedStringResource?
  var message: LocalizedStringResource?
  var preferredStyle: UIAlertController.Style = .alert
  var actions: [AlertAction]
}

private struct AlertPresenter: View {
  @Binding
  var model: Identified<AlertParams>?

  var body: some View {
    if let alert = model?.value {
      ViewControllerRepresentable {
        AlertContainer()
      } updater: { vc in
        guard !vc.wasPresented else { return }
        let alertVC = TrackableAlertController(
          title: alert.title.map { String(localized: $0) },
          message: alert.message.map { String(localized: $0) },
          preferredStyle: alert.preferredStyle
        )
        alertVC.onDismiss = {
          model = nil
        }
        for action in alert.actions {
          alertVC.addAction(action.uiAlertAction)
        }
        vc.alertToPresent = alertVC
      }.background(.red.opacity(0.5))
    }
  }
}

private final class AlertContainer: UIViewController {
  var alertToPresent: UIAlertController? {
    didSet {
      tryPresentAlert()
    }
  }

  var wasPresented = false

  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    tryPresentAlert()
  }

  private func tryPresentAlert() {
    if parent != nil, let alertVC = alertToPresent, !wasPresented {
      wasPresented = true
      alertToPresent = nil
      present(alertVC, animated: true)
    }
  }
}

private final class TrackableAlertController: UIAlertController {
  var onDismiss: Action?

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    onDismiss?()
  }
}

extension View {
  func alert(
    _ alertModel: Binding<Identified<AlertParams>?>
  ) -> some View {
    background {
      AlertPresenter(model: alertModel)
    }
  }
}

extension AlertParams.AlertAction {
  fileprivate var uiAlertAction: UIAlertAction {
    UIAlertAction(
      title: String(localized: title),
      style: style,
      handler: { _ in handler?() }
    )
  }
}

#if DEBUG
#Preview {
  @Previewable @State
  var model: Identified<AlertParams>?

  Button("show alert") {
    model = Identified(value: .mock)
  }.alert($model)
}

extension AlertParams {
  static var mock: AlertParams {
    AlertParams(
      actions: [
        AlertAction(
          title: "Print value",
          style: .default,
          handler: {
            print("Alert action tapped")
          }
        ),
        AlertAction(
          title: "Dismiss",
          style: .cancel
        ),
      ]
    )
  }
}
#endif
