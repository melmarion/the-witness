import Foundation

/// Perlin noise generator — faithful port of the HTML source's n2/fbm functions
final class PerlinNoise {
    private var perm = [Int](repeating: 0, count: 512)
    private let gradients: [[Double]] = [
        [1, 1], [-1, 1], [1, -1], [-1, -1],
        [1, 0], [-1, 0], [0, 1], [0, -1]
    ]

    init(seed: UInt64 = 0) {
        var p = Array(0..<256)
        // Fisher-Yates shuffle with seeded RNG for reproducibility
        var rng = SeededRNG(seed: seed)
        for i in stride(from: 255, through: 1, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            p.swapAt(i, j)
        }
        for i in 0..<256 {
            perm[i] = p[i]
            perm[i + 256] = p[i]
        }
    }

    /// 2D Perlin noise, returns value roughly in [-1, 1]
    func noise2D(_ x: Double, _ y: Double) -> Double {
        let xi = Int(floor(x)) & 255
        let yi = Int(floor(y)) & 255
        let xf = x - floor(x)
        let yf = y - floor(y)
        let u = xf * xf * (3 - 2 * xf)
        let v = yf * yf * (3 - 2 * yf)

        let ga = gradients[perm[perm[xi] + yi] % 8]
        let gb = gradients[perm[perm[xi + 1] + yi] % 8]
        let gc = gradients[perm[perm[xi] + yi + 1] % 8]
        let gd = gradients[perm[perm[xi + 1] + yi + 1] % 8]

        let da = ga[0] * xf + ga[1] * yf
        let db = gb[0] * (xf - 1) + gb[1] * yf
        let dc = gc[0] * xf + gc[1] * (yf - 1)
        let dd = gd[0] * (xf - 1) + gd[1] * (yf - 1)

        return da + u * (db - da) + v * (dc - da) + u * v * (dd - dc - db + da)
    }

    /// Fractal Brownian Motion
    func fbm(_ x: Double, _ y: Double, octaves: Int = 5) -> Double {
        var value = 0.0
        var amplitude = 0.5
        var frequency = 1.0
        for _ in 0..<octaves {
            value += amplitude * noise2D(x * frequency, y * frequency)
            amplitude *= 0.5
            frequency *= 2.1
        }
        return value
    }
}

/// Simple seeded RNG for reproducible noise
struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 12345678901234567 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
