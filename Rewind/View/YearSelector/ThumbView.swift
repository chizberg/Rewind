//
//  ThumbView.swift
//  PhotoPlenka
//
//  Created by Алексей Шерстнёв on 07.02.2022.
//

import UIKit

// TODO: rewrite

/// У ThumbView мы будем использовать три поля:
/// value - значение от 0 до 1 - относительное расположение в баре - используем для сравнения разных
/// thumbView между собой
/// x - координата по х относительно superview - используем для того, чтобы перемещать thumb и для
/// того, чтобы получать value из координаты. x мы можем брать в зависимости от ValueSide
/// year - тут его непосредственно нет, он больше фигурирует в YearSelector, но тут он отображается
/// через yearLabel и backgroundColor
final class ThumbView: UIView {
  private enum Style {
    static let cornerRadius: CGFloat = 15
    static let font = UIFont.systemFont(ofSize: 15, weight: .bold)
    static let horizontalInset: CGFloat = 3
    static let verticalInset: CGFloat = 3
    static let thumbSize: CGSize = .init(width: 60, height: 30)
    static let textColor: UIColor = .white
  }

  /// относительное расположение в YearSelector, от 0 до 1
  /// используем его для конвертации в год
  var value: CGFloat

  let valueSide: ValueSide
  private let yearLabel = UILabel()

  init(value: CGFloat, valueSide type: ValueSide) {
    self.valueSide = type
    self.value = value
    super.init(frame: .zero)

    yearLabel.textAlignment = .center
    yearLabel.font = Style.font
    yearLabel.textColor = Style.textColor
    addSubview(yearLabel)

    layer.cornerRadius = Style.cornerRadius
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    frame.size = Style.thumbSize
    let labelSize = CGSize(
      width: Style.thumbSize.width - Style.horizontalInset * 2,
      height: Style.thumbSize.height - Style.verticalInset * 2
    )
    yearLabel.frame = CGRect(
      origin: CGPoint(x: Style.horizontalInset, y: Style.verticalInset),
      size: labelSize
    )
  }

  func updateYear(_ newYear: Int) {
    yearLabel.text = "\(newYear)"
    backgroundColor = UIColor.from(year: newYear)
  }

  /// Координата по x в superview
  /// её мы изменяем для перемещения, а также считываем для конвертации в value и получения года
  var x: CGFloat {
    get {
      switch valueSide {
      case .left: frame.origin.x
      case .center: center.x
      case .right: frame.origin.x + Style.thumbSize.width
      }
    }
    set {
      switch valueSide {
      case .left: frame.origin.x = newValue
      case .center: center.x = newValue
      case .right: frame.origin.x = newValue - Style.thumbSize.width
      }
    }
  }
}

extension ThumbView {
  /// так как thumb у нас достаточно большой, соответствующее ему значение мы можем брать откуда
  /// захотим
  /// поэтому мы можем брать значение с левой границы, с правой границы или из центра (если будет
  /// нужно)
  enum ValueSide {
    case left
    case center // сейчас не используется
    case right
  }
}
