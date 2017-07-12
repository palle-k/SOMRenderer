//
//  SOMUMatrixRenderer.swift
//  SOMViewer
//
//  Created by Palle Klewitz on 29.04.17.
//  Copyright (c) 2017 Palle Klewitz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.


import Cocoa
import CoreGraphics
import CoreText

import SOMKit

enum ViewMode
{
    case distance
    case feature(index: Int)
    case density(dataset: [Sample])
}


struct SOMUMatrixRenderer: Renderer
{
    let map: SelfOrganizingMap
    var viewMode: ViewMode
    
    var drawsScale: Bool
    var title: String?
    
    init(map: SelfOrganizingMap, mode: ViewMode)
    {
        self.map = map
        self.viewMode = mode
        self.drawsScale = false
        self.title = nil
    }
    
    var aspectRatio: CGFloat
    {
        let width = (Float(map.dimensionSizes[0]) + 0.5) * sqrt(3)
        let height = (Float(map.dimensionSizes[1]) + 1 / 3) * 3 / 2
        
        return CGFloat(width / height)
    }
    
    func estimatedHeight(`for` width: CGFloat) -> CGFloat
    {
        let mapWidth = CGFloat((Float(map.dimensionSizes[0]) + 0.5) * sqrt(3))
        let mapHeight = CGFloat((Float(map.dimensionSizes[1]) + 1 / 3) * 3 / 2)
        
        return width * mapHeight / mapWidth + (drawsScale ? 40 : 0) + (title != nil ? 30 : 0)
    }
    
    func render(`in` context: CGContext, size: CGSize)
    {
        let horizontalScale = size.width / ((CGFloat(map.dimensionSizes[0]) + 0.5) * sqrt(3))
        
        let min: Float
        let max: Float
        
        let minDistance: Float
        let maxDistance: Float
        
        func averageDistance(_ index: [Int]) -> Float
        {
            let node = self.map[index[0], index[1]]
            
            var distanceSum: Float = 0
            var nodeCount = 0
            
            if index[0] > 0
            {
                let neighbour = self.map[index[0]-1, index[1]]
                distanceSum += node.distance(to: neighbour)
                nodeCount += 1
            }
            if index[1] > 0
            {
                let neighbour = self.map[index[0], index[1]-1]
                distanceSum += node.distance(to: neighbour)
                nodeCount += 1
            }
            if index[0] + 1 < self.map.dimensionSizes[0]
            {
                let neighbour = self.map[index[0]+1, index[1]]
                distanceSum += node.distance(to: neighbour)
                nodeCount += 1
            }
            if index[1] + 1 < self.map.dimensionSizes[1]
            {
                let neighbour = self.map[index[0], index[1]+1]
                distanceSum += node.distance(to: neighbour)
                nodeCount += 1
            }
            
            return distanceSum / Float(nodeCount)
        }

        var densities: [Float] = []
        
        switch viewMode
        {
        case .feature(index: let featureIndex):
            min = map.nodes.map{$0[featureIndex]}.min() ?? 0
            max = map.nodes.map{$0[featureIndex]}.max() ?? 1
            
        case .density(let dataset):
            densities = Array<Float>(repeating: 0, count: map.nodes.count)
            
            for sample in dataset
            {
                if let nearestIndex = map.nodes.minIndex(by: sample.compareDistance())
                {
                    densities[nearestIndex] += 1
                }
            }
            
            densities = densities.map{log($0 + 1)}
            
            min = Float(densities.min() ?? 0)
            max = Float(densities.max() ?? 1)
            
        case .distance:
            min = (0..<map.dimensionSizes[0]).flatMap{x in (0..<map.dimensionSizes[1]).map{[x, $0]}}.map(averageDistance).min() ?? 0
            max = (0..<map.dimensionSizes[0]).flatMap{x in (0..<map.dimensionSizes[1]).map{[x, $0]}}.map(averageDistance).max() ?? 1
        }
        
        for y in 0 ..< map.dimensionSizes[1]
        {
            for x in 0 ..< map.dimensionSizes[0]
            {
                switch viewMode
                {
                case .distance:
                    context.setFillColor(.init(gray: CGFloat(1 - (averageDistance([x,y]) - min) / (max - min)), alpha: 1))
                    
                case .feature(index: let featureIndex):
                    let val = map[x,y][featureIndex]
                    context.setFillColor(NSColor(hue: CGFloat((1 - (val - min) / (max - min)) * 2 / 3), saturation: 1, brightness: 1, alpha: 1).cgColor)
                    
                case .density(dataset: _):
                    let index = map.index(for: [x, y])
                    let density = densities[index]
                    context.setFillColor(NSColor(hue: CGFloat((1 - (density - min) / (max - min)) * 2 / 3), saturation: 1, brightness: 1, alpha: 1).cgColor)
                }
                
                let position = CGPoint(
                    x: horizontalScale * sqrt(3) * (CGFloat(x) + (y & 1 == 0 ? 1 : 0.5)),
                    y: horizontalScale * 1.5 * (CGFloat(y) + 0.75)
                )
                
                context.addHexagon(at: position, radius: horizontalScale + 0.25, rotation: 1 / 6 * CGFloat.pi)
                context.fillPath()
            }
        }
        
        if self.drawsScale
        {
            let verticalPosition = size.width / self.aspectRatio + 20
            
            context.saveGState()
            context.translateBy(x: size.width / 2 - 100, y: verticalPosition)
            
            context.clip(to: CGRect(x: 0, y: 0, width: 200, height: 20))
            
            let colors: [CGColor]
            let locations = 100.map{CGFloat($0) / 99}
            
            switch self.viewMode
            {
            case .distance:
                colors = 100.map{CGColor(gray: 1 - CGFloat($0) / 99, alpha: 1)}
                
            case .feature(index: _), .density(dataset: _):
                colors = 100.map{NSColor(hue: (1 - CGFloat($0) / 99) * 2 / 3, saturation: 1, brightness: 1, alpha: 1).cgColor}
            }
            
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 200, y: 0), options: [])
            
            context.restoreGState()
            
            let minString: String
            let maxString: String
            
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 3
            formatter.minimumIntegerDigits = 1
            formatter.decimalSeparator = "."
            
            switch self.viewMode
            {
            case .distance:
                minString = formatter.string(from: NSNumber(value: min))!
                maxString = formatter.string(from: NSNumber(value: max))!
                
            case .feature(index: _), .density(dataset: _):
                minString = formatter.string(from: NSNumber(value: min))!
                maxString = formatter.string(from: NSNumber(value: max))!
            }
			
			let attributes: [NSAttributedStringKey: Any] = [
				NSAttributedStringKey.font: NSFont(name: "Times New Roman", size: 12) as Any
			]
			
			let minLine = CTLineCreateWithAttributedString(NSAttributedString(string: minString, attributes: attributes))
			let maxLine = CTLineCreateWithAttributedString(NSAttributedString(string: maxString, attributes: attributes))
			
            let minBounds = CTLineGetBoundsWithOptions(minLine, [])
            
            context.textPosition = CGPoint(x: size.width / 2 - 110 - minBounds.width, y: verticalPosition + 5)
            CTLineDraw(minLine, context)
            
            context.textPosition = CGPoint(x: size.width / 2 + 110, y: verticalPosition + 5)
            CTLineDraw(maxLine, context)
            
        }
        
        if let title = self.title
        {
            let verticalPosition = size.width / self.aspectRatio + (drawsScale ? 50 : 30)
            
            let attributes: [NSAttributedStringKey: Any] = [
                NSAttributedStringKey.font: NSFont(name: "Times New Roman", size: 16) as Any
            ]
            
            let titleLine = CTLineCreateWithAttributedString(NSAttributedString(string: title, attributes: attributes))
            
            let bounds = CTLineGetBoundsWithOptions(titleLine, [])
            context.textPosition = CGPoint(x: size.width / 2 - bounds.width / 2, y: verticalPosition)
            CTLineDraw(titleLine, context)
        }
    }
}

extension CGContext
{
    func addHexagon(at center: CGPoint, radius: CGFloat, rotation: CGFloat = 0)
    {
        self.beginPath()
        for vertexIndex in 0 ... 5
        {
            let offsetX = cos(rotation + CGFloat(vertexIndex) / 3 * CGFloat.pi) * radius
            let offsetY = sin(rotation + CGFloat(vertexIndex) / 3 * CGFloat.pi) * radius
            (vertexIndex == 0 ? self.move(to:) : addLine(to:))(CGPoint(x: center.x + offsetX, y: center.y + offsetY))
        }
        self.closePath()
    }
}
