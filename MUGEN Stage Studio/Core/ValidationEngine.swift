import Foundation

/// Validates stage documents before export
class ValidationEngine {
    
    /// Validate a stage document
    /// - Parameter document: The document to validate
    /// - Returns: Validation result with errors and warnings
    static func validate(_ document: StageDocument) -> ValidationResult {
        var errors: [ValidationResult.Issue] = []
        var warnings: [ValidationResult.Issue] = []
        
        // Check stage name
        if document.name.isEmpty {
            errors.append(ValidationResult.Issue(
                code: .missingName,
                message: "Enter a stage name before exporting"
            ))
        } else if !isValidFilename(document.name) {
            errors.append(ValidationResult.Issue(
                code: .invalidName,
                message: "Stage name contains invalid characters. Use only letters, numbers, underscores, and hyphens."
            ))
        }
        
        // Check for background layers
        if document.layers.isEmpty {
            errors.append(ValidationResult.Issue(
                code: .noLayers,
                message: "Add at least one background image"
            ))
        }
        
        // Check image dimensions
        if let imageSize = document.imageSize {
            if imageSize.width < 320 || imageSize.height < 240 {
                errors.append(ValidationResult.Issue(
                    code: .imageTooSmall,
                    message: "Image must be at least 320×240 pixels"
                ))
            }
            
            if imageSize.width > 4096 || imageSize.height > 4096 {
                warnings.append(ValidationResult.Issue(
                    code: .imageTooLarge,
                    message: "Images over 4096 pixels may cause performance issues in IKEMEN GO"
                ))
            }
            
            // Check camera bounds vs image size (only for custom resolution with scrolling)
            if document.resolution == .custom, let screenSize = document.resolution.size ?? CGSize(width: 1280, height: 720) as CGSize? {
                let screenWidth = screenSize.width
                let maxPanX = (imageSize.width - screenWidth) / 2
                
                if CGFloat(abs(document.camera.boundLeft)) > maxPanX ||
                   CGFloat(document.camera.boundRight) > maxPanX {
                    warnings.append(ValidationResult.Issue(
                        code: .boundsExceedImage,
                        message: "Camera bounds exceed image width—may show gaps at edges"
                    ))
                }
            }
        }
        
        // Check ground line
        if let imageSize = document.imageSize {
            if document.groundLineY < 0 || CGFloat(document.groundLineY) > imageSize.height {
                errors.append(ValidationResult.Issue(
                    code: .invalidGroundLine,
                    message: "Ground line must be within image bounds"
                ))
            }
        }
        
        // Check player positions - should be within visible screen area
        let screenWidth = document.resolution.size?.width ?? 1280
        let screenHalfWidth = Int(screenWidth / 2)
        let leftBound = -screenHalfWidth + 50
        let rightBound = screenHalfWidth - 50
        
        if document.players.p1X < leftBound || document.players.p1X > rightBound {
            warnings.append(ValidationResult.Issue(
                code: .playerOutOfBounds,
                message: "Player 1 start position is outside recommended bounds"
            ))
        }
        
        if document.players.p2X < leftBound || document.players.p2X > rightBound {
            warnings.append(ValidationResult.Issue(
                code: .playerOutOfBounds,
                message: "Player 2 start position is outside recommended bounds"
            ))
        }
        
        // Check camera bounds validity
        if document.camera.boundLeft >= 0 {
            errors.append(ValidationResult.Issue(
                code: .invalidBounds,
                message: "Camera left bound must be negative"
            ))
        }
        
        if document.camera.boundRight <= 0 {
            errors.append(ValidationResult.Issue(
                code: .invalidBounds,
                message: "Camera right bound must be positive"
            ))
        }
        
        return ValidationResult(errors: errors, warnings: warnings)
    }
    
    /// Check if a string is a valid filename
    private static func isValidFilename(_ name: String) -> Bool {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.rangeOfCharacter(from: invalidCharacters) == nil
    }
}

// MARK: - Validation Result

struct ValidationResult {
    let errors: [Issue]
    let warnings: [Issue]
    
    var isValid: Bool {
        errors.isEmpty
    }
    
    struct Issue {
        let code: IssueCode
        let message: String
    }
    
    enum IssueCode {
        case missingName
        case invalidName
        case noLayers
        case imageTooSmall
        case imageTooLarge
        case boundsExceedImage
        case invalidGroundLine
        case playerOutOfBounds
        case invalidBounds
    }
}
