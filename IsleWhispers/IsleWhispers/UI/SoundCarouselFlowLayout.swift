import UIKit

final class SoundCarouselFlowLayout: UICollectionViewFlowLayout {
    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        scrollDirection = .horizontal
        minimumLineSpacing = 12
        let width = max(collectionView.bounds.width - 56, 1)
        itemSize = CGSize(width: width, height: collectionView.bounds.height)
        sectionInset = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return super.shouldInvalidateLayout(forBoundsChange: newBounds) }
        return newBounds.size != collectionView.bounds.size
    }

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let collectionView else { return proposedContentOffset }
        let target = CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: collectionView.bounds.width,
            height: collectionView.bounds.height
        )
        let centerX = proposedContentOffset.x + collectionView.bounds.width / 2
        let attributes = super.layoutAttributesForElements(in: target) ?? []
        let nearest = attributes.min {
            abs($0.center.x - centerX) < abs($1.center.x - centerX)
        }
        return CGPoint(
            x: (nearest?.center.x ?? centerX) - collectionView.bounds.width / 2,
            y: proposedContentOffset.y
        )
    }
}
