// 生成应用图标：Assets/AppIcon.png（1024 原图）和 Assets/AppIcon.icns
// 用法：在项目根目录运行 swift Assets/make_icon.swift
//
// 图案全部用自定义形状绘制。SF Symbols 的许可不允许用在应用图标里，所以这里不用。
import AppKit
import SwiftUI

// MARK: - 图标图案（1024 × 1024 画布）

/// 一个开关：滑块是头像，表示切换身份；轨道另一侧是 Git 分支图
struct AppIcon: View {
    private let warm = LinearGradient(
        colors: [Color(red: 1.00, green: 0.58, blue: 0.26), Color(red: 0.93, green: 0.25, blue: 0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            // 按 Apple 模板：主体 824 × 824，四周留 100 的边距给阴影
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(warm)
                .overlay(
                    // 上半部分加一层淡淡的高光，增加立体感
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.28), radius: 14, y: 12)

            // 开关轨道
            Capsule()
                .fill(.black.opacity(0.16))
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 8))
                .frame(width: 620, height: 304)

            BranchGlyph()
                .stroke(.white, style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
                .frame(width: 1024, height: 1024)
            ForEach(Array(BranchGlyph.nodes.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
                    .position(point)
            }

            // 滑块：白色圆形，里面是头像
            ZStack {
                Circle().fill(.white)
                Avatar().fill(warm)
            }
            .frame(width: 256, height: 256)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            .position(x: 664, y: 512)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// Git 分支图的连线：一条竖线，中间分出一条弯到右上角
struct BranchGlyph: Shape {
    static let nodes = [CGPoint(x: 340, y: 612), CGPoint(x: 340, y: 412), CGPoint(x: 452, y: 448)]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: Self.nodes[0])
        path.addLine(to: Self.nodes[1])
        path.move(to: CGPoint(x: 340, y: 572))
        path.addCurve(to: Self.nodes[2], control1: CGPoint(x: 340, y: 500), control2: CGPoint(x: 452, y: 530))
        return path
    }
}

/// 头像：圆形的头 + 半圆的肩膀（以 256 × 256 的滑块为坐标）
struct Avatar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 128 - 50, y: 52, width: 100, height: 100))
        path.addEllipse(in: CGRect(x: 128 - 92, y: 168, width: 184, height: 150))
        return path
    }
}

// MARK: - 输出

@MainActor
func renderPNG(pixels: Int) -> Data {
    let renderer = ImageRenderer(content: AppIcon())
    renderer.scale = CGFloat(pixels) / 1024
    guard let cgImage = renderer.cgImage else { fatalError("渲染失败：\(pixels)px") }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("编码 PNG 失败") }
    return data
}

let assets = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

try MainActor.assumeIsolated {
    try renderPNG(pixels: 1024).write(to: assets.appendingPathComponent("AppIcon.png"))
    // iconutil 需要的全部尺寸：每个尺寸都直接按矢量渲染，小图也清晰
    for size in [16, 32, 128, 256, 512] {
        try renderPNG(pixels: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
        try renderPNG(pixels: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil 失败") }
print("✅ 已生成 \(assets.path)/AppIcon.png 和 AppIcon.icns")
