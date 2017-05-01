//
//  SOMInputSpaceRenderer.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 29.04.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import Foundation
import Cocoa
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
