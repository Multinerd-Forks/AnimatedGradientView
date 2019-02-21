//
//  AnimatedGradientView.swift
//  AnimatedGradientView
//
//  Created by Ross Butler on 2/20/19.
//

import Foundation
import UIKit

public class AnimatedGradientView: UIView {
    
    public typealias Animation = AnimatedGradientViewAnimation
    public typealias AnimationValue = (colors: [String], Direction, CAGradientLayerType)
    public typealias Color = AnimatedGradientViewColor
    public typealias Direction = AnimatedGradientViewDirection
    
    public var animations: [Animation]?
    
    public var animationValues: [AnimationValue]? {
        didSet {
            guard let animationValues = animationValues else { return }
            animations = animationValues.map { values in
                Animation(colorStrings: values.colors, direction: values.1, type: values.2)
            }
        }
    }
    
    public var autoAnimate: Bool = true {
        didSet {
            if !autoAnimate {
                stopAnimating()
            }
        }
    }
    
    public var autoRepeat: Bool = true
    
    public var drawsAsynchronously = true {
        didSet {
            gradient?.drawsAsynchronously = drawsAsynchronously
        }
    }
    
    public var colors: [[UIColor]] = [[.purple, .orange]]
    public var colorStrings: [[String]] = [[]] {
        didSet {
            colors = colorStrings.map {
                $0.compactMap { Color(string: $0)?.uiColor }
            }
        }
    }
    public var animationDuration: Double = 3.0
    public var direction: Direction = .up {
        didSet {
            gradient?.startPoint = direction.startPoint
            if type == .radial {
                gradient?.startPoint = CGPoint(x: 0.5, y: 0.5)
            }
            if #available(iOS 12.0, *), type == .conic {
                gradient?.startPoint = CGPoint(x: 0.5, y: 0.5)
            }
            gradient?.endPoint = direction.stopPoint
        }
    }
    public var gridLineColor: UIColor = .white
    public var gridLineOpacity: Float = 0.3
    
    private weak var gradient: CAGradientLayer?
    
    private var currentGradientDirection: Direction {
        if let gradientAnimations = animations {
            return gradientAnimations[gradientColorIndex % gradientAnimations.count].direction
        }
        return direction
    }
    
    private var currentGradientType: CAGradientLayerType {
        if let gradientAnimations = animations {
            return gradientAnimations[gradientColorIndex % gradientAnimations.count].type
        }
        return type
    }
    
    private var gradientCurrentColors: [CGColor] {
        var cgColors: [CGColor]
        if let gradientAnimations = animations {
            let colorStrings = gradientAnimations[gradientColorIndex % gradientAnimations.count].colorStrings
            cgColors = colorStrings.compactMap { Color(string: $0)?.uiColor }.map { $0.cgColor }
        } else {
            cgColors = colors[gradientColorIndex % colors.count]
                .map { $0.cgColor }
        }
        let colorsCountDiff = longestColorArrayCount - cgColors.count
        if colorsCountDiff > 0, let lastColor = cgColors.last {
            cgColors += Array<CGColor>(repeating: lastColor, count: colorsCountDiff)
        }
        return cgColors
    }
    
    private var gradientNextColors: [CGColor] {
        gradientColorIndex += 1
        return gradientCurrentColors
    }
    
    private var gradientColorIndex: Int = 0
    
    private var longestColorArrayCount: Int {
        if let gradientAnimations = animations {
            return gradientAnimations.reduce(0) { (total, animation) in
                let animationColorCount = animation.colorStrings.count
                return animationColorCount > total ? animationColorCount : total
            }
        }
        return colors.reduce(0) { (total, colors) in
            return colors.count > total ? colors.count : total
        }
    }
    
    public var type: CAGradientLayerType = .axial {
        didSet {
            gradient?.type = type
            if type == .axial {
                gradient?.startPoint = direction.startPoint
            }
            if type == .radial {
                gradient?.startPoint = CGPoint(x: 0.5, y: 0.5)
            }
            if #available(iOS 12.0, *), type == .conic {
                gradient?.startPoint = CGPoint(x: 0.5, y: 0.5)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        guard gradient == nil else {
            gradient?.frame = CGRect(origin: CGPoint.zero, size: bounds.size)
            return
        }
        gradient = configuredGradientLayer()
        if let gradientLayer = gradient {
            layer.insertSublayer(gradientLayer, at: 0)
        }
        if autoAnimate {
            animate(gradient, to: gradientNextColors)
        }
    }
}

public extension AnimatedGradientView {
    public func startAnimating() {
        if gradient == nil {
            gradient = configuredGradientLayer()
            if let gradientLayer = gradient {
                layer.insertSublayer(gradientLayer, at: 0)
            }
        }
        stopAnimating()
        animate(gradient, to: gradientNextColors)
    }
    
    public func stopAnimating() {
        gradient?.removeAllAnimations()
    }
}

private extension AnimatedGradientView {
    
    func animate(_ gradient: CAGradientLayer?, to colors: [CGColor]) {
        let locationsAnimation = CABasicAnimation(keyPath: "locations")
        locationsAnimation.fromValue = gradient?.locations
        locationsAnimation.toValue = locations(for: colors)

        let colorsAnimation = CABasicAnimation(keyPath: "colors")
        colorsAnimation.fromValue = gradient?.colors
        colorsAnimation.toValue = colors
        colorsAnimation.fillMode = CAMediaTimingFillMode.forwards
        colorsAnimation.isRemovedOnCompletion = false
        
        let startPointAnimation = CABasicAnimation(keyPath: "startPoint")
        startPointAnimation.delegate = self
        startPointAnimation.fromValue = gradient?.startPoint
        startPointAnimation.toValue = (currentGradientType == .axial) ? currentGradientDirection.startPoint : CGPoint(x: 0.5, y: 0.5)
        
        let endPointAnimation = CABasicAnimation(keyPath: "endPoint")
        endPointAnimation.fromValue = gradient?.endPoint
        endPointAnimation.toValue = currentGradientDirection.stopPoint

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [colorsAnimation, startPointAnimation, endPointAnimation, locationsAnimation]
        animationGroup.duration = animationDuration
        animationGroup.delegate = self
        animationGroup.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        gradient?.add(animationGroup, forKey: "gradient-color-\(gradientColorIndex)")
    }
    
    func locations(for colors: [CGColor]) -> [NSNumber]  {
        let uniqueColors = colors.uniqueMap({ $0 })
        let colorsCountDiff = colors.count - uniqueColors.count
        var result = locations(colorCount: uniqueColors.count)
        if colorsCountDiff > 0, let lastLocation = result.last {
            result = result + Array<NSNumber>(repeating: lastLocation, count: colorsCountDiff)
        }
        return result
    }
    
    func locations(colorCount: Int) -> [NSNumber] {
        var result: [NSNumber] = [0.0]
        if colorCount > 2 {
            let increment = 1.0 / (Double(colorCount) - 1.0)
            var location = increment
            repeat {
                result.append(NSNumber(value: location))
                location += increment
            } while location < 1.0
        }
        result.append(1.0)
        return result
    }
    
    func configuredGradientLayer() -> CAGradientLayer {
        var startPoint = direction.startPoint
        if type == .radial {
            startPoint = CGPoint(x: 0.5, y: 0.5)
        }
        if #available(iOS 12.0, *), type == .conic {
            startPoint = CGPoint(x: 0.5, y: 0.5)
        }
        let stopPoint = direction.stopPoint
        let gradientSize = bounds.size
        let layer = gradientLayer(from: startPoint, to: stopPoint, colors: gradientCurrentColors,
                                  size: gradientSize, drawsAsynchronously: drawsAsynchronously)
        return layer
    }
    
    private func gradientLayer(from startPoint: CGPoint, to stopPoint: CGPoint, colors: [CGColor], size: CGSize, drawsAsynchronously: Bool) -> CAGradientLayer {
        let gradientLayer = CAGradientLayer()
        gradientLayer.drawsAsynchronously = drawsAsynchronously
        gradientLayer.colors = colors
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = stopPoint
        gradientLayer.frame = CGRect(origin: CGPoint.zero, size: size)
        gradientLayer.type = type
        return gradientLayer
    }
    
    func gridLine(from startPoint: CGPoint, to stopPoint: CGPoint, color: UIColor, opacity: Float) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.path = path(from: startPoint, to: stopPoint)
        shape.strokeColor = color.cgColor
        shape.opacity = opacity
        return shape
    }
    
    private func path(from startPoint: CGPoint, to stopPoint: CGPoint) -> CGPath {
        let path = UIBezierPath()
        path.move(to: startPoint)
        path.addLine(to: stopPoint)
        return path.cgPath
    }
}

extension AnimatedGradientView: CAAnimationDelegate {
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag, autoRepeat {
        gradient?.locations = locations(for: gradientCurrentColors)
        gradient?.startPoint = (currentGradientType == .axial) ? currentGradientDirection.startPoint : CGPoint(x: 0.5, y: 0.5)
        gradient?.endPoint = currentGradientDirection.stopPoint
        type = currentGradientType
            animate(gradient, to: gradientNextColors)
        }
    }
}
