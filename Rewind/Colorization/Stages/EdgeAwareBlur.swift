//
//  EdgeAwareBlur.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

import Metal

// A bilateral filter over the Lab triple: a neighbor counts the less the more it differs from the
// pixel at the center, so the model's color is averaged inside an object and not across its
// outline. L is in the weight but never written; README's "Edge-aware blur" has the rest.
// https://doi.org/10.1109/ICCV.1998.710815
enum EdgeAwareBlur {
  // cv2.bilateralFilter's two sigmas, in its units: sigmaColor over the summed channel
  // difference, sigmaSpace over the distance. An explicit diameter wins over sigmaSpace in
  // OpenCV, which then only shapes the falloff inside it, so the window below scales with the
  // frame and these do not.
  // https://docs.opencv.org/4.x/d4/d86/group__imgproc__filter.html#ga9d7064d478c95d60003cf839430737ed
  private static let sigmaColor: Float = 25
  private static let sigmaSpace: Float = 12
  // How wide the window is on a frame of referenceLongSide, in pixels.
  private static let windowAtReference = 15.0
  // This port's own floor, above OpenCV's radius of at least 1: it binds at 373 px and below,
  // where the scaled window rounds to 3 px and the filter all but stops reaching past the pixel.
  private static let minimumDiameter = 5

  static func apply(to ab: ABPlanes, lightness: Plane<Float>) throws -> ABPlanes {
    assert(ab.size == lightness.size)
    let window = ab.size.pixelWindowDiameter(atReference: windowAtReference)
    let diameter = max(minimumDiameter, odd(window))
    return try Shader.shared.run(ab: ab, lightness: lightness, radius: diameter / 2)
  }

  // Forced odd, so the filter has a center pixel to sit on.
  private static func odd(_ value: Double) -> Int {
    let rounded = Int(value.rounded())
    return rounded.isMultiple(of: 2) ? rounded + 1 : rounded
  }

  // Mirrors Uniforms in LabBilateral.metal.
  private struct Uniforms {
    var width: Int32
    var height: Int32
    var radius: Int32
    var colorCoefficient: Float
    var spaceCoefficient: Float
  }

  // 253 neighbors a pixel at the full frame, which is why this is on the GPU. The device, its queue
  // and the pipeline state cost more to build than a run does, so they are built once and kept.
  // Sendable because two screens can colorize at the same time: all three are immutable, and a
  // command queue takes command buffers from several threads at once.
  // https://developer.apple.com/documentation/metal/mtlcommandqueue
  private final class Shader: Sendable {
    static let shared = Shader()

    private let device: MTLDevice?
    private let queue: MTLCommandQueue?
    private let pipeline: MTLComputePipelineState?

    // A threadgroup of 16x16 threads, the shape Apple's compute examples use for a 2D grid.
    // https://developer.apple.com/documentation/metal/calculating-threadgroup-and-grid-sizes
    private static let threadgroupSide = 16

    private init() {
      device = MTLCreateSystemDefaultDevice()
      queue = device?.makeCommandQueue()
      pipeline = device.flatMap { device in
        guard let library = try? device.makeDefaultLibrary(bundle: .main),
              let function = library.makeFunction(name: "labBilateral")
        else {
          return nil
        }
        return try? device.makeComputePipelineState(function: function)
      }
    }

    func run(ab: ABPlanes, lightness: Plane<Float>, radius: Int) throws -> ABPlanes {
      guard let device, let queue else {
        throw HandlingError("Metal is unavailable, unable to smooth the predicted color")
      }
      guard let pipeline else {
        throw HandlingError("The shader that smooths the color is missing from the app")
      }
      let count = ab.size.pixelCount
      let length = count * MemoryLayout<Float>.stride
      func buffer(_ values: [Float]) -> MTLBuffer? {
        device.makeBuffer(bytes: values, length: length, options: .storageModeShared)
      }
      func values(of result: MTLBuffer) -> [Float] {
        let start = result.contents().bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: start, count: count))
      }
      guard let lightnessBuffer = buffer(lightness.values),
            let aBuffer = buffer(ab.a),
            let bBuffer = buffer(ab.b),
            let anchoredA = device.makeBuffer(length: length, options: .storageModeShared),
            let anchoredB = device.makeBuffer(length: length, options: .storageModeShared)
      else {
        throw HandlingError("Not enough memory to smooth the predicted color")
      }
      guard let commands = queue.makeCommandBuffer(),
            let encoder = commands.makeComputeCommandEncoder()
      else {
        throw HandlingError("Unable to hold the predicted color in place")
      }

      var uniforms = Uniforms(
        width: Int32(ab.size.width),
        height: Int32(ab.size.height),
        radius: Int32(radius),
        colorCoefficient: -0.5 / (sigmaColor * sigmaColor),
        spaceCoefficient: -0.5 / (sigmaSpace * sigmaSpace),
      )
      encoder.setComputePipelineState(pipeline)
      encoder.setBuffer(lightnessBuffer, offset: 0, index: 0)
      encoder.setBuffer(aBuffer, offset: 0, index: 1)
      encoder.setBuffer(bBuffer, offset: 0, index: 2)
      encoder.setBuffer(anchoredA, offset: 0, index: 3)
      encoder.setBuffer(anchoredB, offset: 0, index: 4)
      encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 5)
      let threadgroup = MTLSize(
        width: Self.threadgroupSide,
        height: Self.threadgroupSide,
        depth: 1,
      )
      encoder.dispatchThreadgroups(
        MTLSize(
          width: (ab.size.width + threadgroup.width - 1) / threadgroup.width,
          height: (ab.size.height + threadgroup.height - 1) / threadgroup.height,
          depth: 1,
        ),
        threadsPerThreadgroup: threadgroup,
      )
      encoder.endEncoding()
      commands.commit()
      commands.waitUntilCompleted()
      if let error = commands.error {
        throw HandlingError("Unable to smooth the predicted color: \(error.localizedDescription)")
      }

      return ABPlanes(size: ab.size, a: values(of: anchoredA), b: values(of: anchoredB))
    }
  }
}

extension PlaneSize {
  // The long side of the frames the reference measured its window sizes on.
  fileprivate static let referenceLongSide = 1600.0

  // How wide the filter's window is on this frame, for a window of this many pixels on a frame of
  // referenceLongSide. It scales with the frame so that the window covers the same part of the
  // picture whatever size the photo was read at.
  fileprivate func pixelWindowDiameter(atReference pixels: Double) -> Double {
    pixels * Double(max(width, height)) / Self.referenceLongSide
  }
}
