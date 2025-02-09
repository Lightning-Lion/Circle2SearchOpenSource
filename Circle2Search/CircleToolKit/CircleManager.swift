
import SwiftUI
import os

@Observable
class CircleManager {
    var circles:[SpatialCircle] = []
    func createNewCircle() -> SpatialCircle {
        let newCircle = SpatialCircle()
        self.circles.append(newCircle)
        return newCircle
    }
    
}


@Observable
class SpatialCircle:Codable {
    var points:[SIMD3<Float>] = []
    
    var isDone = false
    func addPoint(point:SIMD3<Float>) {
        self.points.append(point)
    }
    func done() {
        if isDone {
            os_log("不要重复调用done()")
        }
        self.isDone = true
    }
}
