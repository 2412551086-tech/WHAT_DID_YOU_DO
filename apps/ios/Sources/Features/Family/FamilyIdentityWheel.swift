import SwiftUI
import UIKit

// Offset zero centers row zero. Silent moves also reset the feedback baseline.
struct FamilyWheelRowTracker {
    private(set) var row: Int?

    static func nearestRow(offset: CGFloat, rowHeight: CGFloat, count: Int) -> Int? {
        guard count > 0, rowHeight > 0, rowHeight.isFinite, offset.isFinite else { return nil }
        return Int(min(CGFloat(count - 1), max(0, (offset / rowHeight).rounded())))
    }

    mutating func move(offset: CGFloat, rowHeight: CGFloat, count: Int, userInitiated: Bool) -> [Int] {
        let next = Self.nearestRow(offset: offset, rowHeight: rowHeight, count: count)
        defer { row = next }
        guard userInitiated, let previous = row, let next, previous != next else { return [] }
        let step = next > previous ? 1 : -1
        return Array(stride(from: previous + step, through: next, by: step))
    }
}

struct FamilyIdentityWheel: View {
    @Binding var selection: String
    var options: [String]

    var body: some View {
        FamilyIdentityWheelBridge(selection: $selection, options: options)
            .frame(height: 220)
    }
}

struct FamilyWheelProjection {
    let angle: CGFloat
    let verticalOffset: CGFloat
    let depth: CGFloat
    let opacity: CGFloat

    static func project(distance: CGFloat, rowHeight: CGFloat, height: CGFloat) -> Self {
        let radius = max(rowHeight, height * 0.48)
        let angle = distance * rowHeight / radius
        guard abs(angle) < .pi / 2 else {
            return Self(angle: angle, verticalOffset: 0, depth: -radius, opacity: 0)
        }
        return Self(angle: angle, verticalOffset: radius * sin(angle),
                    depth: radius * (cos(angle) - 1), opacity: pow(cos(angle), 1.35))
    }
}

private struct FamilyIdentityWheelBridge: UIViewRepresentable {
    @Binding var selection: String
    var options: [String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> FamilyIdentityWheelView {
        FamilyIdentityWheelView()
    }

    func updateUIView(_ view: FamilyIdentityWheelView, context: Context) {
        view.onSelect = { selection = $0 }
        view.reduceMotion = reduceMotion
        view.configure(selection: selection, options: options)
    }
}

private final class FamilyIdentityWheelView: UIView, UIScrollViewDelegate {
    var onSelect: ((String) -> Void)?
    var reduceMotion = false { didSet { updateAppearance() } }
    private let scrollView = UIScrollView()
    private let selectionBand = UIView()
    private let feedback = UISelectionFeedbackGenerator()
    private var labels: [UILabel] = []
    private var options: [String] = []
    private var selectedValue = ""
    private var pending: (selection: String, options: [String])?
    private var tracker = FamilyWheelRowTracker()
    private var interacting = false
    private var synchronizing = false
    private var rowHeight: CGFloat = 44
    private var layoutSize = CGSize.zero
    private var font = UIFont.preferredFont(forTextStyle: .title2)

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        selectionBand.backgroundColor = .tertiarySystemFill
        selectionBand.layer.cornerRadius = 8
        selectionBand.isUserInteractionEnabled = false
        addSubview(selectionBand)
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        scrollView.bounces = false
        scrollView.isAccessibilityElement = false
        scrollView.accessibilityElementsHidden = true
        addSubview(scrollView)
        isAccessibilityElement = true
        accessibilityLabel = "家庭身份"
        accessibilityTraits = .adjustable
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(selection: String, options: [String]) {
        if interacting {
            // Keep the active gesture's rows and geometry stable; newest external state wins.
            pending = selection != selectedValue || options != self.options ? (selection, options) : nil
            return
        }
        let changed = options != self.options
        self.options = options
        selectedValue = selection
        if changed {
            layoutSize = CGSize(width: -1, height: -1)
            labels.forEach { $0.removeFromSuperview() }
            labels = options.map { value in
                let label = UILabel()
                label.text = value
                label.textAlignment = .center
                label.textColor = .label
                label.numberOfLines = 2
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.7
                label.isAccessibilityElement = false
                scrollView.addSubview(label)
                return label
            }
        }
        setNeedsLayout()
        layoutIfNeeded()
        synchronize(row: options.firstIndex(of: selection) ?? 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let newFont = UIFont.preferredFont(forTextStyle: .title2, compatibleWith: traitCollection)
        let metricsChanged = !interacting && newFont != font
        guard bounds.size != layoutSize || metricsChanged || labels.first?.bounds.width != max(0, bounds.width - 32) else {
            updateAppearance()
            return
        }
        let row = tracker.row ?? options.firstIndex(of: selectedValue) ?? 0
        synchronizing = true
        layoutSize = bounds.size
        if !interacting {
            font = newFont
            let lines: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 2 : 1
            rowHeight = max(44, ceil(font.lineHeight * lines + 12))
        }
        scrollView.frame = bounds
        let padding = max(0, (bounds.height - rowHeight) / 2)
        selectionBand.frame = CGRect(x: 8, y: padding, width: max(0, bounds.width - 16), height: rowHeight)
        scrollView.contentSize = CGSize(width: bounds.width, height: padding * 2 + CGFloat(options.count) * rowHeight)
        for (index, label) in labels.enumerated() {
            label.layer.transform = CATransform3DIdentity
            label.font = font
            label.numberOfLines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 2 : 1
            label.bounds = CGRect(x: 0, y: 0, width: max(0, bounds.width - 32), height: rowHeight)
            label.center = CGPoint(x: bounds.midX, y: padding + (CGFloat(index) + 0.5) * rowHeight)
        }
        synchronizing = false
        if !interacting { synchronize(row: row) }
        updateAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsLayout()
    }

    private func synchronize(row: Int) {
        synchronizing = true
        let offset = CGFloat(max(0, min(options.count - 1, row))) * rowHeight
        scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        _ = tracker.move(offset: offset, rowHeight: rowHeight, count: options.count, userInitiated: false)
        synchronizing = false
        updateAppearance()
    }

    private func updateAppearance() {
        let position = scrollView.contentOffset.y / rowHeight
        for (index, label) in labels.enumerated() {
            let distance = CGFloat(index) - position
            let projection = FamilyWheelProjection.project(distance: distance, rowHeight: rowHeight, height: bounds.height)
            label.alpha = projection.opacity
            label.isHidden = projection.opacity == 0
            label.center = CGPoint(x: bounds.midX,
                                   y: scrollView.contentOffset.y + bounds.midY + projection.verticalOffset)
            var transform = CATransform3DIdentity
            if !reduceMotion {
                transform.m34 = -1 / 500
                transform = CATransform3DTranslate(transform, 0, 0, projection.depth)
                transform = CATransform3DRotate(transform, -projection.angle, 1, 0, 0)
            } else {
                transform = CATransform3DScale(transform, 1, max(0.15, cos(projection.angle)), 1)
            }
            label.layer.transform = transform
        }
        accessibilityValue = tracker.row.flatMap { options.indices.contains($0) ? options[$0] : nil }
        accessibilityTraits = options.isEmpty ? [.adjustable, .notEnabled] : .adjustable
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        interacting = true
        _ = tracker.move(offset: scrollView.contentOffset.y, rowHeight: rowHeight, count: options.count, userInitiated: false)
        feedback.prepare()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !synchronizing else { return }
        let crossed = tracker.move(offset: scrollView.contentOffset.y, rowHeight: rowHeight, count: options.count, userInitiated: interacting)
        for _ in crossed {
            feedback.selectionChanged()
            feedback.prepare()
        }
        updateAppearance()
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let row = FamilyWheelRowTracker.nearestRow(offset: targetContentOffset.pointee.y, rowHeight: rowHeight, count: options.count) else { return }
        targetContentOffset.pointee.y = CGFloat(row) * rowHeight
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { finishInteraction() }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        finishInteraction()
    }

    private func finishInteraction() {
        guard interacting else { return }
        interacting = false
        if let pending {
            self.pending = nil
            configure(selection: pending.selection, options: pending.options)
        } else if let row = tracker.row, options.indices.contains(row) {
            selectedValue = options[row]
            synchronize(row: row)
            onSelect?(selectedValue)
        }
        setNeedsLayout()
    }

    override func accessibilityIncrement() { adjust(by: 1) }
    override func accessibilityDecrement() { adjust(by: -1) }

    private func adjust(by delta: Int) {
        guard !interacting, let row = tracker.row, options.indices.contains(row + delta) else { return }
        let next = row + delta
        selectedValue = options[next]
        synchronize(row: next)
        feedback.selectionChanged()
        onSelect?(selectedValue)
    }
}
