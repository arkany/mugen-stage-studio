import Foundation

extension CGRect {
    
    /// Center point of the rectangle
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    
    /// Create a rect centered at a point with given size
    init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
    
    /// Expand rect by given amount on all sides
    func expanded(by amount: CGFloat) -> CGRect {
        return insetBy(dx: -amount, dy: -amount)
    }
}

extension CGPoint {
    
    /// Distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Add two points
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    /// Subtract two points
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}

extension CGSize {
    
    /// Aspect ratio (width / height)
    var aspectRatio: CGFloat {
        guard height > 0 else { return 0 }
        return width / height
    }
    
    /// Scale size to fit within bounds while maintaining aspect ratio
    func scaledToFit(in bounds: CGSize) -> CGSize {
        let widthRatio = bounds.width / width
        let heightRatio = bounds.height / height
        let scale = min(widthRatio, heightRatio)
        return CGSize(width: width * scale, height: height * scale)
    }
    
    /// Scale size to fill bounds while maintaining aspect ratio
    func scaledToFill(_ bounds: CGSize) -> CGSize {
        let widthRatio = bounds.width / width
        let heightRatio = bounds.height / height
        let scale = max(widthRatio, heightRatio)
        return CGSize(width: width * scale, height: height * scale)
    }
}
