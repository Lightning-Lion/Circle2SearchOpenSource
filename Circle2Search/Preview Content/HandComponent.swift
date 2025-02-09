import ARKit
import RealityKit

struct HandComponent: Component {
    var chirality: Chirality
    var provider: AnchorEntityInputProvider
    var thumbTip: AnchorEntity
    var indexFingerTip: AnchorEntity
    
    var currentData: InputData? {
        let thumbTipPosition = thumbTip.position(relativeTo: nil)
        let indexFingerTipPosition = indexFingerTip.position(relativeTo: nil)
        
        // 检查位置是否有效
        if length(thumbTipPosition) < 0.0001 || length(indexFingerTipPosition) < 0.0001 {
            return nil
        }
        
        return InputData(
            thumbTip: thumbTipPosition,
            indexFingerTip: indexFingerTipPosition
        )
    }
}
