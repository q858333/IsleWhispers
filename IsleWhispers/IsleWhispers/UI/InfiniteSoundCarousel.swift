import SnapKit
import UIKit

final class InfiniteSoundCarousel: UIView {
    private static let pageReuseIdentifier = "InfiniteSoundCarouselPage"

    var onSettled: ((Int) -> Void)?
    var onTransition: ((_ from: Int, _ to: Int, _ progress: CGFloat) -> Void)?

    private let sounds: [Sound]
    private let indexing: InfiniteCarouselIndexing
    private let flowLayout: SoundCarouselFlowLayout
    private let collectionView: UICollectionView
    private var positionedSize = CGSize.zero

    private(set) var displayedLogicalIndex: Int
    var physicalItemCount: Int { indexing.physicalItemCount }
    var centeredPhysicalIndex: Int {
        indexing.centeredPhysicalIndex(for: displayedLogicalIndex)
    }
    var collectionAccessibilityElementsHidden: Bool {
        collectionView.accessibilityElementsHidden
    }

    init(sounds: [Sound], selectedIndex: Int) {
        precondition(!sounds.isEmpty)
        let indexing = InfiniteCarouselIndexing(logicalCount: sounds.count)
        let flowLayout = SoundCarouselFlowLayout()

        self.sounds = sounds
        self.indexing = indexing
        self.flowLayout = flowLayout
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        displayedLogicalIndex = indexing.logicalIndex(for: selectedIndex)

        super.init(frame: .zero)
        setupViews()
        updateAccessibilityValue()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard collectionView.bounds.width > 0, collectionView.bounds.height > 0 else { return }
        guard positionedSize != collectionView.bounds.size else { return }

        positionedSize = collectionView.bounds.size
        flowLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        scrollToPhysicalItem(centeredPhysicalIndex, animated: false)
        updateBackgroundTransition()
    }

    func setSelectedSound(index: Int, animated: Bool) {
        let target = indexing.centeredPhysicalIndex(for: index)
        let shouldAnimate = animated
            && !UIAccessibility.isReduceMotionEnabled
            && canAnimateScroll(to: target)
        scrollToPhysicalItem(target, animated: shouldAnimate)
        if !shouldAnimate {
            settle(onPhysicalIndex: target)
        }
    }

    func settle(onPhysicalIndex physicalIndex: Int) {
        let logical = indexing.logicalIndex(for: physicalIndex)
        if let centered = indexing.recenteredPhysicalIndex(after: physicalIndex) {
            scrollToPhysicalItem(centered, animated: false)
        }
        guard logical != displayedLogicalIndex else { return }
        displayedLogicalIndex = logical
        updateAccessibilityValue()
        onSettled?(logical)
    }

    override func accessibilityIncrement() {
        setSelectedSound(index: displayedLogicalIndex + 1, animated: false)
    }

    override func accessibilityDecrement() {
        setSelectedSound(index: displayedLogicalIndex - 1, animated: false)
    }

    private func setupViews() {
        isAccessibilityElement = true
        accessibilityLabel = "环境声音"
        accessibilityTraits = .adjustable

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.accessibilityElementsHidden = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            UICollectionViewCell.self,
            forCellWithReuseIdentifier: Self.pageReuseIdentifier
        )

        addSubview(collectionView)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func updateAccessibilityValue() {
        let sound = sounds[displayedLogicalIndex]
        accessibilityValue = "\(sound.title)，\(displayedLogicalIndex + 1) / \(sounds.count)"
    }

    private func scrollToPhysicalItem(_ physicalIndex: Int, animated: Bool) {
        guard physicalItemCount > 0 else { return }
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(
            at: IndexPath(item: physicalIndex, section: 0),
            at: .centeredHorizontally,
            animated: animated
        )
    }

    private func canAnimateScroll(to physicalIndex: Int) -> Bool {
        guard collectionView.window != nil,
              collectionView.bounds.width > 0,
              collectionView.bounds.height > 0,
              let attributes = flowLayout.layoutAttributesForItem(
                  at: IndexPath(item: physicalIndex, section: 0)
              ) else {
            return false
        }
        let targetOffsetX = attributes.center.x - collectionView.bounds.width / 2
        return abs(targetOffsetX - collectionView.contentOffset.x) > 0.5
    }

    private func closestPhysicalIndex() -> Int {
        let rounded = Int(physicalPosition.rounded())
        return min(max(rounded, 0), physicalItemCount - 1)
    }

    private var physicalPosition: CGFloat {
        let pitch = flowLayout.itemSize.width + flowLayout.minimumLineSpacing
        guard pitch > 0 else { return CGFloat(centeredPhysicalIndex) }
        let firstCenter = flowLayout.sectionInset.left + flowLayout.itemSize.width / 2
        let visibleCenter = collectionView.contentOffset.x + collectionView.bounds.width / 2
        return (visibleCenter - firstCenter) / pitch
    }

    private func updateBackgroundTransition() {
        let position = min(max(physicalPosition, 0), CGFloat(physicalItemCount - 1))
        let lower = Int(floor(position))
        let upper = min(lower + 1, physicalItemCount - 1)
        onTransition?(
            indexing.logicalIndex(for: lower),
            indexing.logicalIndex(for: upper),
            position - CGFloat(lower)
        )
    }
}

extension InfiniteSoundCarousel: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        physicalItemCount
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Self.pageReuseIdentifier,
            for: indexPath
        )
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.isAccessibilityElement = false
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateBackgroundTransition()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settle(onPhysicalIndex: closestPhysicalIndex())
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        settle(onPhysicalIndex: closestPhysicalIndex())
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            settle(onPhysicalIndex: closestPhysicalIndex())
        }
    }
}
