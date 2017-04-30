//
//  SelfOrganizingMap.swift
//  SOMDemo
//
//  Created by Palle Klewitz on 15.02.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import Foundation

typealias SelfOrganizingMapNode = [Float]
typealias Sample = [Float]

class SelfOrganizingMap
{
	let dimensionSizes:[Int]
	
	var dimensions: Int
	{
		return dimensionSizes.count
	}
	
	internal private(set) var nodes: [SelfOrganizingMapNode]
	
	init(_ dimensionSizes: Int..., outputSize: Int)
	{
		self.dimensionSizes = dimensionSizes
		self.nodes = (0 ..< dimensionSizes.reduce(1, *)).map{ _ in (0 ..< outputSize).map{_ in Float.random() * 2 - 1 }}
	}
	
	final subscript(location: Int...) -> SelfOrganizingMapNode
	{
		return nodes[index(for: location)]
	}
	
	final func update(with sample: Sample, totalIterations: Int, currentIteration: Int)
	{
		guard let winningPrototypeIndex = nodes.minIndex(by: Array<Any>.compareDistance(sample)) else { return }
		let winningPrototypeCoordinates = coordinates(for: winningPrototypeIndex)
		
		let neighbourhood = generateNeighbourhood(of: winningPrototypeCoordinates, totalIterations: totalIterations, currentIteration: currentIteration)
		
		for index in self.nodes.indices
		{
			for j in 0 ..< nodes[index].count
			{
				nodes[index][j] += neighbourhood[index] * (sample[j] - nodes[index][j])
			}
		}
	}
	
	private func coordinates(`for` index: Int) -> [Int]
	{
		return dimensionSizes.reduce(([], index), { acc, size in (acc.0 + [acc.1 % size], acc.1 / size)}).0
	}
	
	func index(`for` location: [Int]) -> Int
	{
		precondition(location.count == dimensions, "Location coordinates must have same dimensionality as self organizing map.")
		return zip(location, dimensionSizes).reversed().reduce(0) { $0 * $1.1 + $1.0 }
	}
	
	private func generateNeighbourhood(of: [Int], totalIterations: Int, currentIteration: Int) -> [Float]
	{
//		let nabla_0 = pow(Float(self.nodes.count), 1 / Float(self.dimensions))
		let nabla_0 = Float(self.dimensionSizes.max() ?? 1) / 2
		let lambda = Float(totalIterations) / logf(nabla_0)
		let nabla = nabla_0 * expf(-Float(currentIteration) / lambda)
		let nabla_sq_2 = nabla * nabla * 2
		let alpha = expf(-Float(currentIteration) / lambda)
		
//		let ofFloat = of.map{Float($0)}
		let to = (column: of[0], row: of[1])
		
		let mask =
			nodes.indices
				.map(coordinates)
				.map{(column: $0[0], row: $0[1])}
//				.map{Array<Any>.distance(from: $0, to: ofFloat)}
				.map{Float(hexagonGridDistance(from: $0, to: to))}
		
		return mask.map{expf(-$0 * $0 / nabla_sq_2) * alpha}
	}
}
