//
//  MapBlurView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16.2.25..
//

import SwiftUI

struct MapBlurView: View {
  var thumbnailsEmpty: Bool
  
  var body: some View {
    GeometryReader { proxy in
      VStack {
//        safeAreaFiller
//          .frame(height: proxy.safeAreaInsets.top)
//          .ignoresSafeArea()
        
        Spacer()
        
        thumbnailsFiller
          .ignoresSafeArea()
          .frame(height: 150)
          .opacity(thumbnailsEmpty ? 0 : 1)
          .animation(.default, value: thumbnailsEmpty)
      }
    }
    .allowsHitTesting(false)
  }
  
  private var safeAreaFiller: some View {
    BlurView(style: .regular)
      .mask {
        Rectangle().fill(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .white, location: 0.9),
              .init(color: .white, location: 1)
            ],
            startPoint: .bottom,
            endPoint: .top
          )
        )
      }
  }
  
  private var thumbnailsFiller: some View {
    BlurView(style: .regular)
      .mask {
        Rectangle().fill(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .white, location: 0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      }
  }
}

#Preview {
  @Previewable @State
  var thumbnailsEmpty = false
  
  ZStack {
    Image("cat").resizable().ignoresSafeArea()
    
    MapBlurView(thumbnailsEmpty: thumbnailsEmpty)
      .onTapGesture {
        
      }
    
    Button {
      thumbnailsEmpty.toggle()
    } label: {
      Text("toggle")
        .padding()
        .background(Color.systemBackground)
        .cornerRadius(10)
    }
  }
}
