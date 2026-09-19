//
//  ColorizationPickerScreen.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026..
//

import SwiftUI

struct ColorizationPickerScreen: View {
  var store: ColorizationPickerScreenStore

  var body: some View {
    ScrollViewReader { proxy in
      List {
        content
      }
      .onChange(of: showsColorize) { _, shows in
        if shows {
          withAnimation {
            proxy.scrollTo(colorizeButtonID, anchor: .bottom)
          }
        }
      }
    }
    .interactiveDismissDisabled()
  }

  private var showsColorize: Bool {
    store.colorize != nil && store.common.picked != nil
  }

  @ViewBuilder
  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      ColorizationDemo()

      VStack(alignment: .leading) {
        Text("Image Colorization")
          .font(.title2.bold())
        Text("colorization-feature-promo")
          .font(.footnote.smallCaps().bold())
          .foregroundStyle(
            LinearGradient(
              gradient: makeRainbowGradient(exposureAdjust: -0.5),
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .padding(.bottom, 3)
        VStack(alignment: .leading, spacing: 6) {
          Text("colorization-feature-lead")
          VStack(alignment: .leading, spacing: 2) {
            makeFeatureLine("colorization-feature-free")
            makeFeatureLine("colorization-feature-download-once")
            makeFeatureLine("colorization-feature-seconds")
            makeFeatureLine("colorization-feature-delete-anytime")
          }
        }
        .font(.callout)
      }.padding()
    }
    .listRowInsets(EdgeInsets())

    Section {
      ForEach(store.modelIDs, id: \.self) { id in
        if let state = store.fileStates[id] {
          ModelRow(
            id: id,
            state: state,
            isPicked: store.common.picked == id,
            size: store.common.sizes?[id],
            download: { store(.file(.init(id: id, action: .ui(.download)))) },
            stop: { store(.file(.init(id: id, action: .ui(.cancelDownload)))) },
          )
          .contentShape(Rectangle())
          .onTapGesture { store(.common(.pick(id))) }
          .swipeActions {
            if state == .downloaded {
              Button {
                store(.file(.init(id: id, action: .ui(.delete))))
              } label: {
                Label("Delete", systemImage: "trash")
              }
              .tint(.red)
            }
          }
        }
      }
    } header: {
      Text("Pick a model")
    } footer: {
      if store.colorize != nil {
        Text("You can change the model later in settings")
      }
    }

    if let colorize = store.colorize, store.common.picked != nil {
      Button(action: colorize) {
        ZStack {
          Color.clear.contentShape(Rectangle())
          Text("Colorize")
        }
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal, 10)
      .listRowInsets(EdgeInsets())
      .listRowBackground(EmptyView())
      .id(colorizeButtonID)
    }
  }

  private func makeFeatureLine(_ text: LocalizedStringKey) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text("•")
      Text(text)
      Spacer(minLength: 0)
    }
  }
}

private struct ModelRow: View {
  var id: ColorizationModelID
  var state: ColorizationFileState
  var isPicked: Bool
  var size: String?

  var download: () -> Void
  var stop: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(title(id: id))
          .font(.subheadline.bold())

        HStack(spacing: 3) {
          Text(modelName(id: id))
            .font(.caption.bold().smallCaps())
          if let size {
            Text(" | ")
              .font(.caption.bold().smallCaps())
            Text(size)
              .font(.caption.bold().smallCaps())
          }
        }
        .opacity(0.5)

        Text(description(id: id))
          .font(.callout)
      }

      Spacer()

      DownloadIndicator(
        state: state,
        isPicked: isPicked,
        download: download,
        stop: stop
      )
    }
  }
}

private struct DownloadIndicator: View {
  var state: ColorizationFileState
  var isPicked: Bool
  var download: () -> Void
  var stop: () -> Void

  var body: some View {
    ZStack {
      switch state {
      case .available:
        Button(action: download) {
          Image(systemName: "arrow.down.circle")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
      case let .downloading(progress):
        Button(action: stop) {
          ZStack {
            Circle()
              .stroke(.quaternary, lineWidth: indicatorLineWidth)
            Circle()
              .trim(from: 0, to: progress)
              .stroke(.tint, style: StrokeStyle(lineWidth: indicatorLineWidth, lineCap: .round))
              .rotationEffect(.degrees(-90))
            RoundedRectangle(cornerRadius: 2)
              .fill(.tint)
              .frame(width: 9, height: 9)
          }
        }
        .buttonStyle(.plain)
      case .installing:
        ProgressView()
      case .downloaded:
        if isPicked {
          Image(systemName: "checkmark")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.tint)
            .padding(4)
        }
        EmptyView()
      }
    }
    .frame(width: 28, height: 28)
  }
}

private struct ColorizationDemo: View {
  @State
  private var dividerPosition: CGFloat = 0.5

  var body: some View {
    Image(.colorizationDemoBefore)
      .resizable()
      .scaledToFit()
      .overlay {
        GeometryReader { geometry in
          let width = geometry.size.width
          ZStack {
            Image(.colorizationDemoAfter)
              .resizable()
              .scaledToFit()
              .mask(alignment: .trailing) {
                Rectangle().frame(width: width * (1 - dividerPosition))
              }
            DemoDivider()
              .position(x: dividerX(width: width), y: geometry.size.height / 2)
          }
          .gesture(
            DragGesture().onChanged { value in
              withAnimation(
                .interactiveSpring(
                  response: 0.4,
                  dampingFraction: 0.7,
                  blendDuration: 0.3
                )
              ) {
                dividerPosition = snappedPosition(x: value.location.x, width: width)
              }
            }
          )
        }
      }
      .onAppear(perform: wiggle)
  }

  private func dividerX(width: CGFloat) -> CGFloat {
    min(max(width * dividerPosition, demoDividerWidth / 2), width - demoDividerWidth / 2)
  }

  private func snappedPosition(x: CGFloat, width: CGFloat) -> CGFloat {
    if x < demoDividerWidth / 2 { return 0 }
    if x > width - demoDividerWidth / 2 { return 1 }
    return x / width
  }

  private func wiggle() {
    withAnimation(.smooth(duration: 0.7)) {
      dividerPosition = 0.3
    } completion: {
      withAnimation(.smooth(duration: 1)) {
        dividerPosition = 0.7
      } completion: {
        withAnimation(.smooth(duration: 0.7)) {
          dividerPosition = 0.5
        }
      }
    }
  }
}

private struct DemoDivider: View {
  var body: some View {
    Rectangle()
      .fill(.white)
      .frame(width: 1)
      .overlay {
        Capsule().fill(.white)
          .frame(height: 50)
          .frame(width: demoDividerWidth)
      }
  }
}

private let indicatorLineWidth: CGFloat = 2
private let demoDividerWidth: CGFloat = 10
private let colorizeButtonID = "colorize-button"

private func title(id: ColorizationModelID) -> LocalizedStringKey {
  switch id {
  case .ddColorLarge: "Default"
  case .eccv16: "Compact"
  }
}

private func modelName(id: ColorizationModelID) -> LocalizedStringKey {
  switch id {
  case .ddColorLarge: "DDColor-Large"
  case .eccv16: "ECCV16"
  }
}

private func description(id: ColorizationModelID) -> LocalizedStringKey {
  switch id {
  case .ddColorLarge: "ddcolor-large-description"
  case .eccv16: "eccv16-description"
  }
}

#if DEBUG
extension ColorizationPickerScreenStore {
  static func mock(_ state: ColorizationPickerScreenState) -> ColorizationPickerScreenStore {
    Reducer(
      initial: state,
      reduce: { _, _, _, _ in },
    ).viewStore
  }
}

extension ColorizationPickerScreenState {
  static let mock = ColorizationPickerScreenState(
    fileStates: [.ddColorLarge: .downloaded, .eccv16: .available],
    common: Common(picked: .ddColorLarge),
    modelIDs: ColorizationModelID.allCases,
  )
}

#Preview {
  ColorizationPickerScreen(
    store: .mock(ColorizationPickerScreenState(
      fileStates: [
        .ddColorLarge: .downloaded,
        .eccv16: .downloading(0.4),
      ],
      common: ColorizationPickerScreenState.Common(
        picked: .ddColorLarge,
        sizes: [.ddColorLarge: "421 MB", .eccv16: "120 MB"],
      ),
      modelIDs: ColorizationModelID.allCases,
      colorize: {},
    ))
  )
}

private func makeIndicatorPreview(state: ColorizationFileState) -> some View {
  DownloadIndicator(
    state: state,
    isPicked: true,
    download: {},
    stop: {}
  )
}

#Preview("download indicator") {
  @Previewable @State
  var progress = 0.0

  VStack {
    makeIndicatorPreview(state: .available)
    makeIndicatorPreview(state: .downloading(progress))
      .onAppear {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
          progress = 1
        }
      }
    makeIndicatorPreview(state: .installing)
    makeIndicatorPreview(state: .downloaded)
  }
}

#Preview("demo") {
  ColorizationDemo()
}
#endif
