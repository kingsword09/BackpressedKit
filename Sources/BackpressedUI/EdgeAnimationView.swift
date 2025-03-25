//
//  EdgeAnimationView.swift
//  tauri-plugin-mobile-onbackpressed-listener
//
//  Created by kingsword09 on 2025/3/7.
//

import UIKit

// @see: https://github.com/BioforestChain/dweb_browser/blob/6dcb4b14e6f394ca015cf01925b2c4ac8afb494d/next/kmp/app/iosApp/DwebBrowser/DwebBrowser/Desktop/EdgeAnimationView.swift#L11
public class EdgeAnimationView: UIView {
    var edge: UIRectEdge = .left
    var triggerAction: () -> Void = {}

    private let fullWidth: Int = 60
    private var initFrame: CGRect = .zero
    private var originalWidth: CGFloat = 0.0
    private var initialOriginX: CGFloat = 0.0 // 添加初始的 x 坐标变量

    private var animator: UIViewPropertyAnimator?
    private let shapeLayer = CAShapeLayer()
    private let iconView = UIImageView(frame: .zero)
    private var cachedPaths = [CGPath]()
    
    public init(frame: CGRect, rectEdge: UIRectEdge, trigger: @escaping () -> Void) {
        super.init(frame: frame)
        edge = rectEdge
        generateCachedPaths()
        triggerAction = trigger
        initFrame = frame
        configUI()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configUI() {
        layer.addSublayer(shapeLayer)
        shapeLayer.fillColor = UIColor.clear.withAlphaComponent(0.3).cgColor
        shapeLayer.strokeColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 3.0
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        addGestureRecognizer(panGesture)
        
        iconView.frame = bounds
        iconView.image = UIImage(systemName: edge == .right ? "chevron.left" : "chevron.right")
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        if edge == .right {
            NSLayoutConstraint.activate([
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.leftAnchor.constraint(equalTo: leftAnchor, constant: 8),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.rightAnchor.constraint(equalTo: rightAnchor, constant: -8),
            ])
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()

        drawShapeLayer()
    }
    
    private func drawShapeLayer() {
        if cachedPaths.isEmpty { return }

        // 更新layer的路径
        var indexWidth = Int(frame.width)
        if indexWidth >= cachedPaths.count {
            indexWidth = cachedPaths.count - 1
        }
        shapeLayer.path = cachedPaths[indexWidth]
        shapeLayer.frame = bounds
    }
    
    private func generateCachedPaths() {
        let height = frame.height
        let rectEdge = edge
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 1...self.fullWidth {
                Task { @MainActor in
                    let path = EdgeAnimationView.generatePath(for: i, height: height, edge: rectEdge)
                    self.cachedPaths.append(path)
                }
            }
        }
    }
    
    @objc public func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: superview)
        
        switch sender.state {
        case .began, .changed:
            let gesPoint = sender.location(in: sender.view)
            let newY = gesPoint.y - initFrame.height / 2
            initFrame = CGRect(x: initFrame.minX, y: newY, width: initFrame.width, height: initFrame.height)
        default:
            break
        }
        switch sender.state {
        case .began:
            // 如果有正在进行的动画，停止并完成它
            if let animator = animator, animator.isRunning {
                stopAnimation()
            } else {
                // 这是每次新触发的手势。 否则如果有动画在进行，二次拖拽动画则建立在前一个动画位置之上
                frame = initFrame
            }
            originalWidth = bounds.width
            initialOriginX = translation.x // self.frame.origin.x // 记录初始的 x 坐标
            drawShapeLayer()
        case .changed:
            if edge == .left {
                let newWidth = max(0, min(translation.x - initialOriginX + originalWidth, CGFloat(fullWidth)))
                frame = CGRect(x: initFrame.minX, y: initFrame.minY, width: newWidth, height: initFrame.height)
            } else {
                let newWidth = max(0, min(initialOriginX - translation.x + originalWidth, CGFloat(fullWidth)))
                let newX = initFrame.minX - newWidth
                frame = CGRect(x: newX, y: initFrame.minY, width: newWidth, height: initFrame.height)
            }
            iconView.alpha = ((frame.width / CGFloat(fullWidth)) > 0.7) ? 1.0 : 0.5
        case .ended, .cancelled:
            if (frame.width / CGFloat(fullWidth)) > 0.7 {
                // 执行用户动作
                triggerAction()
                // 轻微的震动
                let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                impactFeedbackGenerator.prepare()
                impactFeedbackGenerator.impactOccurred()
            }
            startAnimation()
        default:
            break
        }
    }
    
    private func animateBackToOriginalWidth(_ duration: Double) {
        let uianimator = UIViewPropertyAnimator(
            duration: duration,
            controlPoint1: CGPoint(x: 0, y: 0.95),
            controlPoint2: CGPoint(x: 0.5, y: 1)
        ) {
            self.frame = self.initFrame
        }
        animator = uianimator
        
        // 确保动画完成后才释放
        uianimator.addCompletion { position in
            if position == .end && self.animator == uianimator {
                self.animator = nil
            }
        }
        
        uianimator.startAnimation()
    }
    
    private func animateShapes(_ duration: Double) {
        let currentWidth = Int(frame.width)
        let index = min(currentWidth, cachedPaths.count - 1)
        let subArray = Array(cachedPaths[0...index].reversed())
        let animation = CAKeyframeAnimation(keyPath: "path")
        animation.values = subArray
        animation.duration = duration // 动画持续时间
        let timingFunction = CAMediaTimingFunction(controlPoints: 0, 0.95, 0.5, 1)
        animation.timingFunction = timingFunction
        shapeLayer.add(animation, forKey: "shapeAnimation")
    }
    
    func startAnimation() {
        let duration = 0.6
        animateShapes(duration)
        animateBackToOriginalWidth(duration)
    }

    func stopAnimation() {
        animator?.stopAnimation(true)
        animator?.finishAnimation(at: .current)
        // if let currentPath = shapeLayer.presentation()?.path {
        //     // 在停止动画时，将当前路径设置为 shapeLayer 的路径，避免一闪现象
        //     shapeLayer.path = currentPath
        // }
        // 二次拖拽时，需要停止前一次的回原动画，通过 key 来移除动画，这里使用添加动画时的 key
        shapeLayer.removeAnimation(forKey: "shapeAnimation")
    }
    
    private static func generatePath(for indexWidth: Int, height: CGFloat, edge: UIRectEdge) -> CGPath {
        let bezPath = UIBezierPath()
        let width = CGFloat(indexWidth)
        if edge == .left {
            bezPath.move(to: CGPoint.zero)
            bezPath.addCurve(to: CGPoint(x: width, y: height / 2),
                             controlPoint1: CGPoint(x: 0, y: height / 4),
                             controlPoint2: CGPoint(x: width, y: height / 3.3))
            bezPath.addCurve(to: CGPoint(x: 0, y: height),
                             controlPoint1: CGPoint(x: width, y: height * 2.3 / 3.3),
                             controlPoint2: CGPoint(x: 0, y: height * 3.0 / 4))
        } else {
            bezPath.move(to: CGPoint(x: width, y: 0))
            bezPath.addCurve(to: CGPoint(x: 0, y: height / 2),
                             controlPoint1: CGPoint(x: width, y: height / 4),
                             controlPoint2: CGPoint(x: 0, y: height / 3.3))
            bezPath.addCurve(to: CGPoint(x: width, y: height),
                             controlPoint1: CGPoint(x: 0, y: height * 2.3 / 3.3),
                             controlPoint2: CGPoint(x: width, y: height * 3.0 / 4))
        }
        return bezPath.cgPath
    }
}
