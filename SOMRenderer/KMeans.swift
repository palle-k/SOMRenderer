//
//  KMeans.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 30.04.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import Foundation
import Accelerate


class KMeansClusterer
{
	private(set) var dataset: [Sample]
	private(set) var clusterCenters: [Sample]
	
	public init(dataset: [Sample], clusterCount: Int)
	{
		self.dataset = dataset
		self.clusterCenters = clusterCount.map{_ in dataset.random()}
	}
	
	func performIteration() -> Bool
	{
		let currentCenters = self.clusterCenters
		
		var clusters = Array<[Sample]>(repeating: [], count: clusterCenters.count)
		
		for sample in dataset
		{
			guard let nearestClusterIndex = clusterCenters.minIndex(by: Array<Any>.compareDistance(sample)) else
			{
				continue
			}
			clusters[nearestClusterIndex].append(sample)
		}
		
		for i in 0 ..< clusterCenters.count
		{
			var sum = Array<Float>(repeating: 0, count: dataset[0].count)
			
			for sample in clusters[i]
			{
				vDSP_vadd(sample, 1, sum, 1, &sum, 1, UInt(sample.count))
			}
			
			vDSP_vsdiv(sum, 1, [max(Float(clusters[i].count), 1)], &sum, 1, UInt(sum.count))
			clusterCenters[i] = sum
		}
		
		return !zip(clusterCenters, currentCenters).map{$0 == $1}.reduce(true, {$0 && $1})
	}
	
	func samples(`for` clusterIndex: Int) -> [Sample]
	{
		return dataset.filter { sample -> Bool in
			guard let nearestClusterIndex = clusterCenters.minIndex(by: Array<Any>.compareDistance(sample)) else
			{
				return false
			}
			return nearestClusterIndex == clusterIndex
		}
	}
}
