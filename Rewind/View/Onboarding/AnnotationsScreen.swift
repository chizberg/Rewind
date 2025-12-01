//
//  AnnotationsScreen.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 28. 11. 2025..
//

import MapKit
import SwiftUI

struct AnnotationsScreen: View {
  var goNext: () -> Void

  var body: some View {
    VStack(alignment: .leading) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Old photos on a map")
          .multilineTextAlignment(.leading)
          .font(.largeTitle.bold())

        Text("What do they look like?")
          .fontWeight(.semibold)
          .padding(.top, 2)
      }.padding(.horizontal)

      Spacer()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(spacing: 5) {
            makeAnnotationDescription(
              annotation: ImageAnnotationView(
                annotation: AnnotationWrapper(value: .image(.demo)),
                reuseIdentifier: nil
              ),
              title: "single_image_title",
              description: "single_image_description"
            )
            makeAnnotationDescription(
              annotation: MergedAnnotationView(
                annotation: AnnotationWrapper(
                  value: .localCluster(.demo)
                ),
                reuseIdentifier: nil
              ),
              title: "group_of_images_title",
              description: "group_of_images_description"
            )
            makeAnnotationDescription(
              annotation: ClusterAnnotationView(
                annotation: AnnotationWrapper(
                  value: .cluster(.demo)
                ),
                reuseIdentifier: nil
              ),
              title: "cluster_of_images_title",
              description: "cluster_of_images_description"
            )
          }

          VStack {
            Text("onboarding_date")
            Divider()
            YearSelector(yearRange: .constant(1826...2000))
              .allowsHitTesting(false)
          }
          .onboardingCard()

          Text("onboarding_pastvu")
            .font(.footnote)
            .opacity(0.5)
            .padding(.horizontal, 7)

          HStack {
            Text("onboarding_location")
            Spacer(minLength: 0)
          }.onboardingCard()
        }
        .padding(.top, 20)
        .padding(.horizontal)
        .padding(.bottom, 80)
      }
      .overlay(alignment: .bottom) {
        HStack {
          Spacer()
          Button(action: goNext) {
            Text("Let's see!")
              .padding(7)
          }
          .prominent()
          Spacer()
        }
        .padding()
        .background {
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .systemBackground, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .ignoresSafeArea()
        }
      }
    }
    .frame(maxWidth: 500, maxHeight: 900)
  }

  func makeAnnotationDescription(
    annotation: MKAnnotationView,
    title: LocalizedStringKey,
    description: LocalizedStringKey
  ) -> some View {
    HStack {
      ViewRepresentable {
        AnnotationViewContainer(
          annotationView: annotation
        )
      }
      .frame(squareSize: 60)
      .padding(.trailing, 7)
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

private final class AnnotationViewContainer: UIView {
  let annotationView: MKAnnotationView

  init(annotationView: MKAnnotationView) {
    self.annotationView = annotationView
    super.init(frame: .zero)
    addSubview(annotationView)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("unavailable")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    annotationView.center = bounds.center
  }
}

extension Model.Image {
  fileprivate static let demo = Model.Image(
    Network.Image(
      cid: 0,
      file: "",
      title: "",
      dir: "n",
      geo: [0, 0],
      year: 1861,
      year2: 1861
    ),
    image: .demo
  )
}

extension Model.LocalCluster {
  fileprivate static let demo = Model.LocalCluster(
    images: [.demo, .demo, .demo],
    coordinate: Model.Image.demo.coordinate
  )
}

extension Model.Cluster {
  fileprivate static let demo = Model.Cluster(
    preview: .demo,
    coordinate: Model.Image.demo.coordinate,
    count: 150
  )
}

extension LoadableUIImage {
  fileprivate static let demo = LoadableUIImage { _ in .demo }
}

#if DEBUG
#Preview("Annotations") {
  AnnotationsScreen(goNext: {})
}
#endif
