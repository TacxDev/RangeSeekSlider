//
//  RangeSeekSlider.swift
//  RangeSeekSlider
//
//  Created by Keisuke Shoji on 2017/03/09.
//
//

import UIKit

@IBDesignable open class RangeSeekSlider: UIControl {
    private struct Constant {
        static let barSidePadding: CGFloat = 2.0
    }
    
    // MARK: - initializers

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    public required override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    public convenience init(frame: CGRect = .zero, completion: ((RangeSeekSlider) -> Void)? = nil) {
        self.init(frame: frame)
        completion?(self)
    }

    // MARK: - open stored properties

    open weak var delegate: RangeSeekSliderDelegate?

    /// The minimum possible value to select in the range
    @IBInspectable open var minValue: CGFloat = 0.0 {
        didSet {
            refresh()
        }
    }

    /// The maximum possible value to select in the range
    @IBInspectable open var maxValue: CGFloat = 100.0 {
        didSet {
            refresh()
        }
    }

    /// The preselected minumum value
    /// (note: This should be less than the selectedMaxValue)
    @IBInspectable open var selectedMinValue: CGFloat = 0.0 {
        didSet {
            if selectedMinValue < minValue {
                selectedMinValue = minValue
            }
            
            layoutContent()
        }
    }

    /// The preselected maximum value
    /// (note: This should be greater than the selectedMinValue)
    @IBInspectable open var selectedMaxValue: CGFloat = 100.0 {
        didSet {
            if selectedMaxValue > maxValue {
                selectedMaxValue = maxValue
            }
            
            layoutContent()
        }
    }

    /// The minimum distance the two selected slider values must be apart. Default is 0.
    @IBInspectable open var minDistance: CGFloat = 0.0 {
        didSet {
            if minDistance < 0.0 {
                minDistance = 0.0
            }
        }
    }

    /// The maximum distance the two selected slider values must be apart. Default is CGFloat.greatestFiniteMagnitude.
    @IBInspectable open var maxDistance: CGFloat = .greatestFiniteMagnitude {
        didSet {
            if maxDistance < 0.0 {
                maxDistance = .greatestFiniteMagnitude
            }
        }
    }

    /// Set slider line tint color between handles
    @IBInspectable open var colorBetweenHandles: UIColor?

    /// The color of the entire slider when the handle is set to the minimum value and the maximum value. Default is nil.
    @IBInspectable open var initialColor: UIColor?

    /// If true, the control will mimic a normal slider and have only one handle rather than a range.
    /// In this case, the selectedMinValue will be not functional anymore. Use selectedMaxValue instead to determine the value the user has selected.
    @IBInspectable open var disableRange: Bool = false {
        didSet {
            leftHandle.isHidden = disableRange
        }
    }

    /// If true the control will snap to point at each step between minValue and maxValue. Default is false.
    @IBInspectable open var enableStep: Bool = false

    /// The step value, this control the value of each step. If not set the default is 0.0.
    /// (note: this is ignored if <= 0.0)
    @IBInspectable open var step: CGFloat = 0.0

    /// Left handle slider with custom image, you can set custom image for your handle
    @IBInspectable open var leftHandleImage: UIImage? {
        didSet {
            guard let image = leftHandleImage else {
                return
            }
            
            leftHandle.contents = image.cgImage
            layoutContent()
        }
    }
    
    /// Right handle slider with custom image, you can set custom image for your handle
    @IBInspectable open var rightHandleImage: UIImage? {
        didSet {
            guard let image = rightHandleImage else {
                return
            }
            
            rightHandle.contents = image.cgImage
            layoutContent()
        }
    }

    /// Set the slider line height (default 1.0)
    @IBInspectable open var lineHeight: CGFloat = 1.0 {
        didSet {
            updateLineHeight()
        }
    }

    // MARK: - private stored properties

    private enum HandleTracking { case none, left, right }
    private var handleTracking: HandleTracking = .none

    private let sliderLine: CALayer = CALayer()
    private let sliderLineBetweenHandles: CALayer = CALayer()

    private let leftHandle: CALayer = CALayer()
    private let rightHandle: CALayer = CALayer()

    // UIFeedbackGenerator
    private var previousStepMinValue: CGFloat?
    private var previousStepMaxValue: CGFloat?

    // MARK: - UIView

    open override func layoutSubviews() {
        super.layoutSubviews()

        // update the frames in a transaction so that the tracking doesn't continue until the frame has moved.
        performLayerAnimation {
            updateLineHeight()
            updateColors()
            updateHandlePositions()
        }
    }
    
    private func performLayerAnimation(_ animations: () -> ()) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animations()
        CATransaction.commit()
    }

    open override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 65.0)
    }

    // MARK: - UIControl

    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let touchLocation: CGPoint = touch.location(in: self)
        let insetExpansion: CGFloat = -30.0
        let isTouchingLeftHandle: Bool = leftHandle.frame.insetBy(dx: insetExpansion, dy: insetExpansion).contains(touchLocation)
        let isTouchingRightHandle: Bool = rightHandle.frame.insetBy(dx: insetExpansion, dy: insetExpansion).contains(touchLocation)

        guard isTouchingLeftHandle || isTouchingRightHandle else { return false }

        // the touch was inside one of the handles so we're definitely going to start movign one of them. But the handles might be quite close to each other, so now we need to find out which handle the touch was closest too, and activate that one.
        let distanceFromLeftHandle: CGFloat = touchLocation.distance(to: leftHandle.frame.center)
        let distanceFromRightHandle: CGFloat = touchLocation.distance(to: rightHandle.frame.center)

        if distanceFromLeftHandle < distanceFromRightHandle && !disableRange {
            handleTracking = .left
        } else if selectedMaxValue == maxValue && leftHandle.frame.midX == rightHandle.frame.midX {
            handleTracking = .left
        } else {
            handleTracking = .right
        }

        delegate?.didStartTouches(in: self)

        return true
    }

    open override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard handleTracking != .none else { return false }

        let location: CGPoint = touch.location(in: self)
        let selectedValue = valueAlongTheLine(for: location.x)

        switch handleTracking {
        case .left:
            selectedMinValue = min(selectedValue, selectedMaxValue)
        case .right:
            // don't let the dots cross over, (unless range is disabled, in which case just dont let the dot fall off the end of the screen)
            if disableRange && selectedValue >= minValue {
                selectedMaxValue = selectedValue
            } else {
                selectedMaxValue = max(selectedValue, selectedMinValue)
            }
        case .none:
            // no need to refresh the view because it is done as a side-effect of setting the property
            break
        }

        refresh()

        return true
    }

    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        handleTracking = .none

        delegate?.didEndTouches(in: self)
    }

    // MARK: - open methods

    /// When subclassing **RangeSeekSlider** and setting each item in **setupStyle()**, the design is reflected in Interface Builder as well.
    open func setupStyle() {}

    // MARK: - private methods

    private func setup() {
        // draw the slider line
        layer.addSublayer(sliderLine)

        // draw the track distline
        layer.addSublayer(sliderLineBetweenHandles)

        layer.addSublayer(leftHandle)
        layer.addSublayer(rightHandle)

        let handleFrame: CGRect = CGRect(x: 0.0, y: 0.0, width: 16, height: 16)
        leftHandle.frame = handleFrame
        rightHandle.frame = handleFrame

        setupStyle()

        refresh()
    }
    
    private func valueAlongTheLine(for xPosition: CGFloat) -> CGFloat {
        let leftHandleWidth = leftHandleImage?.size.width ?? 0
        let rightHandleWidth = rightHandleImage?.size.width ?? 0

        // find out the percentage along the line we are in x coordinate terms (subtracting half the frames width to account for moving the middle of the handle, not the left hand side)
        
        let sliderLineLeft = sliderLine.frame.minX + leftHandleWidth / 2
        let sliderLineRight = sliderLine.frame.maxX - rightHandleWidth / 2
        let percentage: CGFloat = (xPosition - sliderLineLeft) / (sliderLineRight - sliderLineLeft)
                
        // multiply that percentage by self.maxValue to get the new selected minimum value
        let selectedValue: CGFloat = percentage * (maxValue - minValue) + minValue
        
        return selectedValue
    }

    private func xPositionAlongLine(for value: CGFloat) -> CGFloat {
        let leftHandleWidth = leftHandleImage?.size.width ?? 0
        let rightHandleWidth = rightHandleImage?.size.width ?? 0

        let percentage: CGFloat = (minValue < maxValue) ? (value - minValue) / (maxValue - minValue) : 0
        let maxMinDif: CGFloat = frame.width - leftHandleWidth/2 - rightHandleWidth/2

        return leftHandleWidth/2 + percentage * maxMinDif
    }

    private func updateLineHeight() {
        let yMiddle: CGFloat = frame.height / 2.0
        let lineLeftSide: CGPoint = CGPoint(x: Constant.barSidePadding, y: yMiddle)
        let lineRightSide: CGPoint = CGPoint(x: frame.width - Constant.barSidePadding,
                                             y: yMiddle)
        sliderLine.frame = CGRect(x: lineLeftSide.x,
                                  y: lineLeftSide.y,
                                  width: lineRightSide.x - lineLeftSide.x,
                                  height: lineHeight)
        sliderLine.cornerRadius = lineHeight / 2.0
        sliderLineBetweenHandles.cornerRadius = sliderLine.cornerRadius
    }

    private func updateColors() {
        let isInitial: Bool = selectedMinValue == minValue && selectedMaxValue == maxValue
        if let initialColor = initialColor?.cgColor, isInitial {
            sliderLineBetweenHandles.backgroundColor = initialColor
            sliderLine.backgroundColor = initialColor

            let leftColor: CGColor = (leftHandleImage == nil) ? initialColor : UIColor.clear.cgColor
            leftHandle.backgroundColor = leftColor
            leftHandle.borderColor = leftColor
            
            let rightColor: CGColor = (rightHandleImage == nil) ? initialColor : UIColor.clear.cgColor
            rightHandle.backgroundColor = rightColor
            rightHandle.borderColor = rightColor
        } else {
            let tintCGColor: CGColor = tintColor.cgColor
            sliderLineBetweenHandles.backgroundColor = colorBetweenHandles?.cgColor ?? tintCGColor
            sliderLine.backgroundColor = tintCGColor
        }
    }

    private func updateHandlePositions() {
        let leftHandleCenter = CGPoint(x: xPositionAlongLine(for: selectedMinValue),
                                       y: sliderLine.frame.midY)
        let rightHandleCenter = CGPoint(x: xPositionAlongLine(for: selectedMaxValue),
                                        y: sliderLine.frame.midY)
        
        leftHandle.frame = CGRect(center: leftHandleCenter, size: leftHandleImage?.size ?? .zero)
        rightHandle.frame = CGRect(center: rightHandleCenter, size: rightHandleImage?.size ?? .zero)
        
        // positioning for the dist slider line
        sliderLineBetweenHandles.frame = CGRect(x: leftHandle.position.x,
                                                y: sliderLine.frame.minY,
                                                width: rightHandle.position.x - leftHandle.position.x,
                                                height: lineHeight)
    }
    
    fileprivate func refresh() {
        if enableStep && step > 0.0 {
            selectedMinValue = CGFloat(roundf(Float(selectedMinValue / step))) * step
            if let previousStepMinValue = previousStepMinValue, previousStepMinValue != selectedMinValue {
                TapticEngine.selection.feedback()
            }
            previousStepMinValue = selectedMinValue

            selectedMaxValue = CGFloat(roundf(Float(selectedMaxValue / step))) * step
            if let previousStepMaxValue = previousStepMaxValue, previousStepMaxValue != selectedMaxValue {
                TapticEngine.selection.feedback()
            }
            previousStepMaxValue = selectedMaxValue
        }

        let diff: CGFloat = selectedMaxValue - selectedMinValue

        if diff < minDistance {
            switch handleTracking {
            case .left:
                selectedMinValue = selectedMaxValue - minDistance
            case .right:
                selectedMaxValue = selectedMinValue + minDistance
            case .none:
                break
            }
        } else if diff > maxDistance {
            switch handleTracking {
            case .left:
                selectedMinValue = selectedMaxValue - maxDistance
            case .right:
                selectedMaxValue = selectedMinValue + maxDistance
            case .none:
                break
            }
        }

        // ensure the minimum and maximum selected values are within range. Access the values directly so we don't cause this refresh method to be called again (otherwise changing the properties causes a refresh)
        if selectedMinValue < minValue {
            selectedMinValue = minValue
        }
        if selectedMaxValue > maxValue {
            selectedMaxValue = maxValue
        }

        layoutContent()

        updateColors()

        // update the delegate
        if let delegate = delegate, handleTracking != .none {
            delegate.rangeSeekSlider(self, didChange: selectedMinValue, maxValue: selectedMaxValue)
        }
    }
    
    private func layoutContent() {
        setNeedsLayout()
        
//        UIView.performWithoutAnimation {
//            layoutIfNeeded()
//        }
    }
}

// MARK: - CGRect

private extension CGRect {

    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2,
                  y: center.y - size.height / 2,
                  width: size.width,
                  height: size.height)
    }
}

// MARK: - CGPoint

private extension CGPoint {

    func distance(to: CGPoint) -> CGFloat {
        let distX: CGFloat = to.x - x
        let distY: CGFloat = to.y - y
        return sqrt(distX * distX + distY * distY)
    }
}
