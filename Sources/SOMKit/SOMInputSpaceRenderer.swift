//
//  SOMInputSpaceRenderer.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 29.04.17.
//	Copyright (c) 2017 Palle Klewitz
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//	SOFTWARE.


import CoreGraphics

/// A Renderer draws something into a CGContext.
public protocol Renderer {
	
	/// Performs the rendering
	///
	/// - Parameters:
	///   - context: Context into which is drawn
	///   - size: The object must be drawn smaller than the size.
	func render(`in` context: CGContext, size: CGSize)
}


/// A renderer which renders the nodes of a Self-Organizing Map
/// in the input space
public struct SOMInputSpaceRenderer: Renderer {
	public enum MapType {
		case grid
		case hexagonal
	}
	
	
	/// The map to be drawn
	public let map: SelfOrganizingMap
	public let mapType: MapType
	
	/// Creates a new renderer which renders a given Self-Organizing Map
	/// in the input space.
	///
	/// - Parameter map: Map to be drawn
	public init(map: SelfOrganizingMap, type: MapType) {
		self.map = map
		self.mapType = type
	}
	
	
	public func render(in context: CGContext, size: CGSize)
	{
		// Determining the bounds of the Self-Organizing Map in the input space
		let minX: Float = 0
		let maxX: Float = 1
		
		let minY: Float = 0
		let maxY: Float = 1
		
		let horizontalScale = size.width / CGFloat(maxX - minX)
		let verticalScale = size.height / CGFloat(maxY - minY)
		
		context.setStrokeColor(.black)
		
		// Drawing the self organizing map
		if mapType == .grid {
			for y in 0 ..< map.dimensionSizes[1] {
				for x in 0 ..< map.dimensionSizes[0] {
					if x > 0 {
						context.move(
							to: CGPoint(
								x: CGFloat(map[x, y][0] - minX) * horizontalScale,
								y: CGFloat(map[x, y][1] - minY) * verticalScale
							)
						)
						context.addLine(
							to: CGPoint(
								x: CGFloat(map[x-1, y][0] - minX) * horizontalScale,
								y: CGFloat(map[x-1, y][1] - minY) * verticalScale
							)
						)
					}
					if y > 0 {
						context.move(
							to: CGPoint(
								x: CGFloat(map[x, y][0] - minX) * horizontalScale,
								y: CGFloat(map[x, y][1] - minY) * verticalScale
							)
						)
						context.addLine(
							to: CGPoint(
								x: CGFloat(map[x, y-1][0] - minX) * horizontalScale,
								y: CGFloat(map[x, y-1][1] - minY) * verticalScale
							)
						)
					}
					if x < map.dimensionSizes[0] - 1 {
						context.move(
							to: CGPoint(
								x: CGFloat(map[x, y][0] - minX) * horizontalScale,
								y: CGFloat(map[x, y][1] - minY) * verticalScale
							)
						)
						context.addLine(
							to: CGPoint(
								x: CGFloat(map[x+1, y][0] - minX) * horizontalScale,
								y: CGFloat(map[x+1, y][1] - minY) * verticalScale
							)
						)
					}
					if y < map.dimensionSizes[1] - 1 {
						context.move(
							to: CGPoint(
								x: CGFloat(map[x, y][0] - minX) * horizontalScale,
								y: CGFloat(map[x, y][1] - minY) * verticalScale
							)
						)
						context.addLine(
							to: CGPoint(
								x: CGFloat(map[x, y+1][0] - minX) * horizontalScale,
								y: CGFloat(map[x, y+1][1] - minY) * verticalScale
							)
						)
					}
				}
			}
		} else {
			for y in 0 ..< map.dimensionSizes[1] {
				for x in 0 ..< map.dimensionSizes[0] {
					// Topological horizontal connection to the next node on the right
					
					if x < map.dimensionSizes[0] - 1 {
						context.move(
							to: CGPoint(
								x: CGFloat(map[x, y][0] - minX) * horizontalScale,
								y: CGFloat(map[x, y][1] - minY) * verticalScale
							)
						)
						context.addLine(
							to: CGPoint(
								x: CGFloat(map[x+1, y][0] - minX) * horizontalScale,
								y: CGFloat(map[x+1, y][1] - minY) * verticalScale
							)
						)
					}
					
					// Topological vertical connections to the nodes in the row below
					
					if y < map.dimensionSizes[1] - 1 {
						if y & 1 == 1
						{
							// If the row is uneven, a node is connected to the
							// node to the left one row below and to the node directly below.
							
							context.move(
								to: CGPoint(
									x: CGFloat(map[x, y][0] - minX) * horizontalScale,
									y: CGFloat(map[x, y][1] - minY) * verticalScale
								)
							)
							context.addLine(
								to: CGPoint(
									x: CGFloat(map[x, y+1][0] - minX) * horizontalScale,
									y: CGFloat(map[x, y+1][1] - minY) * verticalScale
								)
							)
							
							if x > 0
							{
								context.move(
									to: CGPoint(
										x: CGFloat(map[x, y][0] - minX) * horizontalScale,
										y: CGFloat(map[x, y][1] - minY) * verticalScale
									)
								)
								context.addLine(
									to: CGPoint(
										x: CGFloat(map[x-1, y+1][0] - minX) * horizontalScale,
										y: CGFloat(map[x-1, y+1][1] - minY) * verticalScale
									)
								)
							}
							
						} else {
							// If the row is uneven, a node is connected to the
							// node directly below and the node below to the right.
							
							context.move(
								to: CGPoint(
									x: CGFloat(map[x, y][0] - minX) * horizontalScale,
									y: CGFloat(map[x, y][1] - minY) * verticalScale
								)
							)
							context.addLine(
								to: CGPoint(
									x: CGFloat(map[x, y+1][0] - minX) * horizontalScale,
									y: CGFloat(map[x, y+1][1] - minY) * verticalScale
								)
							)
							
							if x < map.dimensionSizes[0] - 1
							{
								context.move(
									to: CGPoint(
										x: CGFloat(map[x, y][0] - minX) * horizontalScale,
										y: CGFloat(map[x, y][1] - minY) * verticalScale
									)
								)
								context.addLine(
									to: CGPoint(
										x: CGFloat(map[x+1, y+1][0] - minX) * horizontalScale,
										y: CGFloat(map[x+1, y+1][1] - minY) * verticalScale
									)
								)
							}
							
						} // if y is uneven
					} // if y < map.dimensionSizes[1] - 1
					
				} // for x
			} // for y
		}
		
		context.strokePath()
		
	}
	
}
