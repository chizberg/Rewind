//
//  UIKitYearSelector.swift
//  PhotoPlenka
//
//  Created by Алексей Шерстнёв on 07.02.2022.
//

import SwiftUI
import UIKit

// TODO: rewrite

final class UIKitYearSelector: UIView {
  private enum Constants {
    static let lineHeight: CGFloat = 7
    static let lineRadius: CGFloat = lineHeight / 2
    static let horizontalLineInset: CGFloat = 33
    static let thumbWidth: CGFloat = 60
    // так как у нас значения thumbView берутся с границ, то мы возможные значения thumbView.x
    // ограничиваем ещё на половину thumbWidth (изначально у нас thumbView.center.x =
    // horizontalLineInset)
    static let valueInset: CGFloat = horizontalLineInset + thumbWidth / 2
    static let startYear: Int = 1826
    static let endYear: Int = 2000
  }

  private let thumbs: [ThumbView]

  // MARK: - public values

  var yearRange: ClosedRange<Int> {
    let year1 = year(from: thumbs[0].value)
    let year2 = year(from: thumbs[1].value)
    guard year1 < year2 else { return year2...year1 }
    return year1...year2
  }

  var valueRange: ClosedRange<CGFloat> {
    thumbs[0].value...thumbs[1].value
  }

  // MARK: - views

  private lazy var line: UIView = {
    let view = UIView()
    view.layer.insertSublayer(gradientLayer, at: 0)
    view.layer.cornerRadius = Constants.lineRadius
    view.clipsToBounds = true
    return view
  }()

  /// shadows - серые линии вместо градиента за пределами выбранного отрезка
  private let leftLineShadow: UIView = {
    let view = UIView()
    view.backgroundColor = .yearLineShadowColor
    view.layer.cornerRadius = Constants.lineRadius
    return view
  }()

  private let rightLineShadow: UIView = {
    let view = UIView()
    view.backgroundColor = .yearLineShadowColor
    view.layer.cornerRadius = Constants.lineRadius
    return view
  }()

  private let gradientLayer = CAGradientLayer.yearGradient()
  private var panRecognizers = [UIPanGestureRecognizer]()

  @Binding var yearRangeBinding: ClosedRange<Int>

  init(yearRange binding: Binding<ClosedRange<Int>>) {
    self._yearRangeBinding = binding
    thumbs = [
      .init(
        value: lerpParameter(
          of: CGFloat(binding.wrappedValue.lowerBound),
          lowerBound: CGFloat(Constants.startYear),
          upperBound: CGFloat(Constants.endYear)
        ),
        valueSide: .right
      ),
      .init(
        value: lerpParameter(
          of: CGFloat(binding.wrappedValue.upperBound),
          lowerBound: CGFloat(Constants.startYear),
          upperBound: CGFloat(Constants.endYear)
        ),
        valueSide: .left
      ),
    ]
    super.init(frame: .zero)

    addSubview(line)
    addSubview(leftLineShadow)
    addSubview(rightLineShadow)

    for thumb in thumbs {
      let pan = UIPanGestureRecognizer(target: self, action: #selector(dragThumb(_:)))
      panRecognizers.append(pan)
      thumb.isUserInteractionEnabled = true
      thumb.addGestureRecognizer(pan)
      addSubview(thumb)
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let lineOrigin = CGPoint(
      x: Constants.horizontalLineInset,
      y: bounds.midY - Constants.lineHeight / 2
    )
    line.frame = CGRect(
      origin: lineOrigin,
      size: CGSize(
        width: bounds.width - Constants.horizontalLineInset * 2,
        height: Constants.lineHeight
      )
    )
    CATransaction.performWithoutAnimations {
      gradientLayer.frame = line.bounds
    }

    updateThumbCoordinates()
    updateShadows()
  }

  @objc func dragThumb(_ sender: UIPanGestureRecognizer) {
    guard let thumb = sender.view as? ThumbView else { return }
    let translation = sender.translation(in: self)
    move(thumb: thumb, xDiff: translation.x)
    sender.setTranslation(.zero, in: self)
  }

  private func move(thumb: ThumbView, xDiff: CGFloat) {
    var newX = thumb.x + xDiff
    var newValue = value(from: newX)

    // ограничение на перемещение thumbView
    if newValue > 1 { newValue = 1; newX = x(from: newValue) }
    if newValue < 0 { newValue = 0; newX = x(from: newValue) }

    // обработка столкновений: thumb'ы не должны пересекаться
    // и если мы их сталкиваем, то они должны двигаться - прикольно
    switch thumb.valueSide {
    case .left:
      let leftThumb = thumbs[0]
      if leftThumb.value > newValue {
        move(thumb: leftThumb, xDiff: thumb.x - leftThumb.x)
      }
    case .right:
      let rightThumb = thumbs[1]
      if rightThumb.value < newValue {
        move(thumb: rightThumb, xDiff: thumb.x - rightThumb.x)
      }
    case .center: break
    }

    // получив новые значения, применяем их на thumb
    thumb.updateYear(year(from: newValue))
    thumb.x = newX
    thumb.value = newValue
    rangeDidChange()
  }

  private func rangeDidChange() {
    yearRangeBinding = yearRange
    updateShadows()
  }

  /// ставит thumbs в нужные места в зависимости от выставленных значений
  private func updateThumbCoordinates() {
    for thumb in thumbs {
      thumb.frame.origin.y = 10
      thumb.x = x(from: thumb.value)
      thumb.updateYear(year(from: thumb.value))
    }
  }

  private func updateShadows() {
    let leftOriginX = Constants.horizontalLineInset
    let rightOriginX = thumbs[1].center.x
    let originY = bounds.midY - Constants.lineHeight / 2
    let height = Constants.lineHeight

    // левая тень - от начала линии до первого (левого) thumb
    let leftShadowWidth = thumbs[0].center.x - leftOriginX
    let leftOrigin = CGPoint(x: leftOriginX, y: originY)
    leftLineShadow.frame = CGRect(
      origin: leftOrigin,
      size: CGSize(width: leftShadowWidth, height: height)
    )

    // правая тень - от второго (правого) thumb
    let rightShadowWidth = bounds.width - Constants.horizontalLineInset - rightOriginX
    let rightOrigin = CGPoint(x: rightOriginX, y: originY)
    rightLineShadow.frame = CGRect(
      origin: rightOrigin,
      size: CGSize(width: rightShadowWidth, height: height)
    )
  }

  // MARK: - converting funcs

  /// value - относительное расположение thumbView - от 0 до 1
  /// так как у нас значения берутся с краёв, а не с середин, мы берём valueInset
  /// value = x внутри отрезка возможных значений, разделённый на длину этого отрезка
  private func value(from x: CGFloat) -> CGFloat {
    let minX = Constants.valueInset
    let maxX = bounds.width - Constants.valueInset
    return (x - minX) / (maxX - minX)
  }

  /// ищем координату thumbView исходя из value
  private func x(from value: CGFloat) -> CGFloat {
    let minX = Constants.valueInset
    let maxX = bounds.width - Constants.valueInset
    return minX + (maxX - minX) * value
  }

  private func year(from value: CGFloat) -> Int {
    Constants.startYear + Int(CGFloat(Constants.endYear - Constants.startYear) * value)
  }
}

extension UIColor {
  static var yearLineShadowColor: UIColor {
    UIColor { traits -> UIColor in
      traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemGray3
    }
  }
}

extension CAGradientLayer {
  static func yearGradient() -> CAGradientLayer {
    let gradientLayer = CAGradientLayer()
    gradientLayer.type = .axial
    gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
    gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)

    gradientLayer.locations = []
    gradientLayer.colors = []

    for point in pastvuGradient {
      let (value, color) = (point.position, point.value)
      gradientLayer.locations?.append(NSNumber(value: value))
      gradientLayer.colors?.append(color.systemColor.cgColor)
    }

    return gradientLayer
  }
}
