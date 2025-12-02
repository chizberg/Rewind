//
//  DelayedModifier.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 2. 12. 2025..
//

import SwiftUI

private struct DelayedContainer<
  T: Equatable,
  Content: View
>: View {
  @State
  private var innerValue: T
  @MainActor @State
  private var task: Task<Void, Never>?

  private var value: T
  private var delay: TimeInterval
  @ViewBuilder
  private var content: (T) -> Content

  init(
    value: T,
    delay: TimeInterval,
    @ViewBuilder content: @escaping (T) -> Content
  ) {
    innerValue = value
    self.value = value
    self.delay = delay
    self.content = content
  }

  var body: some View {
    content(innerValue)
      .onChange(of: value) {
        let newValue = value
        task?.cancel()
        task = Task {
          do {
            try await Task.sleep(for: .seconds(delay))
            await MainActor.run {
              innerValue = newValue
            }
          } catch {
            if !(error is CancellationError) {
              assertionFailure("unexpected error: \(error)")
            }
          }
        }
      }
  }
}

extension View {
  @ViewBuilder
  func delayedModifier<T: Equatable>(
    value: T,
    delay: TimeInterval,
    transform: @escaping (Self, T) -> some View
  ) -> some View {
    DelayedContainer(
      value: value,
      delay: delay
    ) { value in
      transform(self, value)
    }
  }
}

#if DEBUG
#Preview {
  @Previewable @State
  var count = 0

  VStack {
    DelayedContainer(
      value: count,
      delay: count % 2 == 0 ? 1 : 0
    ) { value in
      Text("\(value)")
    }

    Button(String("Increment")) {
      count += 1
    }
  }
}

#Preview("corners") {
  @Previewable @State
  var overlayPresented = false // just for testing

  VStack {
    Color.blue
      .frame(squareSize: 200)
      .delayedModifier(
        value: overlayPresented,
        delay: overlayPresented ? 0 : 1
      ) { view, value in
        view.mask(
          RoundedRectangle(cornerRadius: value ? 30 : 0)
        )
      }

    Button(String("Toggle, now \(overlayPresented)")) {
      overlayPresented.toggle()
    }
  }
}
#endif
