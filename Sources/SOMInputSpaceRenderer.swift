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


protocol SOMRenderer: class
{
	func render(`in` context: CGContext, size: CGSize)
}

class SOMInputSpaceRenderer: SOMRenderer
{
	let map: SelfOrganizingMap
	
	init(map: SelfOrganizingMap)
	{
		self.map = map
	}
	
	func render(in context: CGContext, size: CGSize)
	{
		let minX = self.map.nodes.map{$0[0]}.min() ?? 0
		let maxX = self.map.nodes.map{$0[0]}.max() ?? 1
		
		let minY = self.map.nodes.map{$0[1]}.min() ?? 0
		let maxY = self.map.nodes.map{$0[1]}.max() ?? 1
		
		let horizontalScale = size.width / CGFloat(maxX - minX)
		let verticalScale = size.height / CGFloat(maxY - minY)
		
		context.setStrokeColor(.black)
		
		for y in 0 ..< map.dimensionSizes[1]
		{
			for x in 0 ..< map.dimensionSizes[0]
			{
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
							x: CGFloat(map[x+1, y][0] - minX) * horizontalScale,
							y: CGFloat(map[x+1, y][1] - minY) * verticalScale
						)
					)
				}
				
				if y < map.dimensionSizes[1] - 1
				{
					if y & 1 == 1
					{
						// uneven row, connected to next: 0, -1
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
						
					}
					else
					{
						// even row, connected to next: 0, 1
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
		context.strokePath()
		
	}
	
}
