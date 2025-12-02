//
//  WelcomeScreen.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 28. 11. 2025..
//

import SwiftUI

struct WelcomeScreen: View {
  var goNext: () -> Void

  var body: some View {
    VStack(alignment: .leading) {
      Spacer()
        .frame(height: 50)

      VStack(alignment: .leading, spacing: 8) {
        Text("Hi!")
          .font(.largeTitle.bold())
        HStack {
          (Text("This is ") + Text("Rewind").foregroundStyle(rewindRed))
            .font(.largeTitle.bold())
          RewindCapsule()
          Spacer(minLength: 0)
        }

        Text("A time-travel app")
          .fontWeight(.semibold)
          .padding(.top, 2)
      }.padding(.horizontal)

      Spacer()

      ScrollView {
        VStack(spacing: 10) {
          makeFeatureDescription(
            iconName: "mappin.and.ellipse",
            title: "history_near_you_title",
            description: "history_near_you_description"
          )
          makeFeatureDescription(
            iconName: "star",
            title: "images_saving_title",
            description: "images_saving_description"
          )
          makeFeatureDescription(
            iconName: "camera.viewfinder",
            title: "comparison_title",
            description: "comparison_description"
          )
        }
        .padding(.top, 20)
        .padding(.horizontal)
      }

      Spacer()

      HStack {
        Spacer()
        Button(action: goNext) {
          Text("Get started")
            .padding(7)
        }
        .prominent()
        Spacer()
      }
      .padding()
    }
    .frame(maxWidth: 500, maxHeight: 900)
  }

  func makeFeatureDescription(
    iconName: String,
    title: LocalizedStringKey,
    description: LocalizedStringKey
  ) -> some View {
    HStack {
      Image(systemName: iconName)
        .font(.title)
        .foregroundStyle(Color.accentColor)
        .frame(width: 40)
        .padding(.trailing, 5)
        .padding(.leading, 3)
      VStack(alignment: .leading) {
        Text(title)
          .font(.headline)
        Text(description)
      }
      Spacer(minLength: 0)
    }
    .onboardingCard()
  }
}

private struct RewindCapsule: View {
  var body: some View {
    capsuleContainer {
      Image(systemName: "backward.fill")
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
  }

  @ViewBuilder
  func capsuleContainer(
    content: () -> some View
  ) -> some View {
    if #available(iOS 26, *) {
      content().glassEffect(.regular.tint(rewindRed), in: Capsule())
    } else {
      content()
        .background {
          Capsule().fill(rewindRed)
        }
    }
  }
}

#if DEBUG
#Preview("Welcome") {
  WelcomeScreen(goNext: {})
}
#endif
