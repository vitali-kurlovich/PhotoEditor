# PhotoEditor

A SwiftUI photo editor for iOS and macOS built around **cinematic, LUT-based color grading**. Rather than another set of vintage or nostalgic presets, it applies the same `.cube` look-up tables colorists use in film and photography, giving photos a rich, editorial look. Everything is rendered on the GPU through Core Image and Metal.

## Demo

[![PhotoEditor demo 1](https://img.youtube.com/vi/mhlkwJTqYLM/0.jpg)](https://youtu.be/mhlkwJTqYLM)
[![PhotoEditor demo 2](https://img.youtube.com/vi/JHe07xnMoDo/0.jpg)](https://youtu.be/JHe07xnMoDo)

## Features

- **LUT color grading.** Loads and parses Adobe/Resolve `.cube` 3D LUT files and applies them with `CIColorCube`. The app ships with bundled film and neon presets.
- **Built-in Core Image looks:** Mono, Noir, Chrome, Instant, Fade, Process, Transfer, Sepia, Vibrance, Comic and Invert.
- **Before/after comparison.** View the original, the filtered result, or a split view with a draggable divider.
- **Metal rendering.** Previews are drawn into an `MTKView` through a shared `CIContext` backed by Metal.
- **Photo library integration.** Pick photos with PhotoKit, with EXIF orientation handled, and save edited images back to Photos.
- **Video generation.** Export a short H.264 clip (6 s, 30 fps) that fades the original into the graded image, built with `AVAssetWriter`.
- **AI image generation over MCP.** Connect to any MCP server over HTTP, browse and run its tools, and show the images they return. A dedicated Hugging Face screen generates images from a text prompt through `https://huggingface.co/mcp`, and you can then grade the result like any other photo. Tokens are stored in the Keychain.

## Tech stack

| Area | Frameworks |
| --- | --- |
| UI | SwiftUI, Observation |
| Image processing | Core Image, Metal / MetalKit |
| Media | PhotoKit, AVFoundation |
| Networking | [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) |
| Math | [swift-mathkit](https://github.com/vitali-kurlovich/swift-mathkit) |

## Requirements

- iOS 18.6+ / macOS 15.6+
- A recent version of Xcode. Swift Package dependencies resolve automatically.

## Getting started

```bash
git clone https://github.com/vitali-kurlovich/PhotoEditor.git
```

```bash
open PhotoEditor/PhotoEditor/PhotoEditor.xcodeproj
```

Select the **PhotoEditor** scheme, choose an iOS device, simulator or *My Mac*, and run.

To use Hugging Face image generation, create an access token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) and paste it into the app's Hugging Face screen.

## Adding your own LUTs

1. Add a `.cube` file to `PhotoEditor/PhotoEditor/Bundle/` and include it in the app target.
2. Add its file name, without the extension, to `LUTBundle.fileNames` in `Filters/LUT/LUTBundle.swift`.

## Project structure

```
PhotoEditor/PhotoEditor/
├── Filters/        Filter types, picker, and .cube LUT parser
├── Editor/         Image editor with original/split/filtered modes
├── Photo/          Main screen, view model, video preview
├── MCP/            MCP server browser, tool runner, Hugging Face prompt
├── Camera/         Camera preview (work in progress)
├── Core/           Metal context, video exporter, photo library, Keychain, MCP client
└── Bundle/         Bundled .cube LUT presets
```
