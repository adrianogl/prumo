import AppKit
import CoreGraphics
import Foundation

let root = FileManager.default.currentDirectoryPath
let svgPath = "\(root)/docs/mockups/pull-request-carbon.svg"
let iconSet = "\(root)/PRumo/Resources/Assets.xcassets/AppIcon.appiconset"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let svg = try? String(contentsOfFile: svgPath, encoding: .utf8) else { fail("SVG não encontrado: \(svgPath)") }

func pathData(in svg: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: "<path[^>]*\\sd=\"([^\"]+)\"") else { return [] }
    let range = NSRange(svg.startIndex..., in: svg)
    return regex.matches(in: svg, range: range).compactMap {
        Range($0.range(at: 1), in: svg).map { String(svg[$0]) }
    }
}

enum Token {
    case command(Character)
    case number(Double)
}

func tokenize(_ data: String) -> [Token] {
    guard let regex = try? NSRegularExpression(pattern: "[a-zA-Z]|-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?") else { return [] }
    let range = NSRange(data.startIndex..., in: data)
    return regex.matches(in: data, range: range).compactMap { match in
        guard let r = Range(match.range, in: data) else { return nil }
        let text = String(data[r])
        if let first = text.first, first.isLetter { return .command(first) }
        return Double(text).map { .number($0) }
    }
}

func buildPath(_ data: String) -> CGPath {
    let path = CGMutablePath()
    let tokens = tokenize(data)
    var index = 0
    var current = CGPoint.zero
    var start = CGPoint.zero
    var lastControl: CGPoint?
    var command: Character = "m"

    func next() -> Double {
        guard index < tokens.count, case .number(let value) = tokens[index] else { fail("número esperado em \(index)") }
        index += 1
        return value
    }

    while index < tokens.count {
        if case .command(let c) = tokens[index] {
            command = c
            index += 1
            if c == "z" || c == "Z" {
                path.closeSubpath()
                current = start
                lastControl = nil
                continue
            }
        }
        let relative = command.isLowercase
        let ox = relative ? current.x : 0
        let oy = relative ? current.y : 0
        switch Character(command.lowercased()) {
        case "m":
            let p = CGPoint(x: ox + next(), y: oy + next())
            path.move(to: p)
            current = p
            start = p
            command = relative ? "l" : "L"
            lastControl = nil
        case "l":
            let p = CGPoint(x: ox + next(), y: oy + next())
            path.addLine(to: p)
            current = p
            lastControl = nil
        case "h":
            let p = CGPoint(x: ox + next(), y: current.y)
            path.addLine(to: p)
            current = p
            lastControl = nil
        case "v":
            let p = CGPoint(x: current.x, y: oy + next())
            path.addLine(to: p)
            current = p
            lastControl = nil
        case "c":
            let c1 = CGPoint(x: ox + next(), y: oy + next())
            let c2 = CGPoint(x: ox + next(), y: oy + next())
            let p = CGPoint(x: ox + next(), y: oy + next())
            path.addCurve(to: p, control1: c1, control2: c2)
            current = p
            lastControl = c2
        case "s":
            let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
            let c2 = CGPoint(x: ox + next(), y: oy + next())
            let p = CGPoint(x: ox + next(), y: oy + next())
            path.addCurve(to: p, control1: c1, control2: c2)
            current = p
            lastControl = c2
        default:
            fail("comando não suportado: \(command)")
        }
    }
    return path
}

let paths = pathData(in: svg).map(buildPath)
guard paths.count == 2 else { fail("esperava 2 paths, achei \(paths.count)") }

func hex(_ value: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((value >> 16) & 0xff) / 255,
        green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255,
        alpha: 1
    )
}

func render(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fail("sem contexto") }

    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [hex(0xf3e6cf), hex(0xd9c3a0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])
    ctx.restoreGState()

    let symbol = size * 0.64
    let scale = symbol / 32
    ctx.translateBy(x: (size - symbol) / 2, y: (size - symbol) / 2)
    ctx.scaleBy(x: scale, y: scale)

    ctx.setFillColor(hex(0xa5713a))
    ctx.addPath(paths[0])
    ctx.fillPath()
    ctx.setFillColor(hex(0x2a2622))
    ctx.addPath(paths[1])
    ctx.fillPath()

    guard let image = ctx.makeImage() else { fail("sem imagem") }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let png = rep.representation(using: .png, properties: [:]) else { fail("sem PNG") }
    return png
}

struct Slot { let size: Int; let scale: Int }
let slots = [16, 32, 128, 256, 512].flatMap { [Slot(size: $0, scale: 1), Slot(size: $0, scale: 2)] }

var images: [[String: String]] = []
for slot in slots {
    let pixels = slot.size * slot.scale
    let name = "icon_\(slot.size)x\(slot.size)@\(slot.scale)x.png"
    do {
        try render(pixels: pixels).write(to: URL(fileURLWithPath: "\(iconSet)/\(name)"))
    } catch {
        fail("falha ao gravar \(name): \(error)")
    }
    images.append([
        "filename": name,
        "idiom": "mac",
        "scale": "\(slot.scale)x",
        "size": "\(slot.size)x\(slot.size)",
    ])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: URL(fileURLWithPath: "\(iconSet)/Contents.json"))
print("gerados \(images.count) PNGs em \(iconSet)")
