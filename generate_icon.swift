import Cocoa

// Usage: swift generate_icon.swift <input_svg_path> <output_png_path>
// Example: swift generate_icon.swift app-icon.svg icon_1024.png

let args = CommandLine.arguments

guard args.count >= 3 else {
    print("Usage: swift generate_icon.swift <input.svg> <output.png>")
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2] // Expected to be full path

// 1. Load the SVG
guard let image = NSImage(contentsOfFile: inputPath) else {
    print("Error: Could not load image from \(inputPath)")
    exit(1)
}

// 2. Define target size (High resolution for master icon)
let targetSize = CGSize(width: 1024, height: 1024)
let targetRect = NSRect(origin: .zero, size: targetSize)

// 3. Create a new image with expected size (transparency preserved by default in NSImage)
let newImage = NSImage(size: targetSize)

newImage.lockFocus()
// Draw the loaded image into the context
image.draw(in: targetRect, from: NSRect.zero, operation: .copy, fraction: 1.0)
newImage.unlockFocus()

// 4. Convert to PNG
guard let tiffData = newImage.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Error: Could not convert to PNG")
    exit(1)
}

// 5. Write to file
do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Successfully created transparent PNG at \(outputPath)")
} catch {
    print("Error writing file: \(error)")
    exit(1)
}
