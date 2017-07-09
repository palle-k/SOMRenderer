//
//  KMeans.swift
//  SOMRenderer
//
//  Created by Palle Klewitz on 30.04.17.
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
				vDSP_vadd(sample, 1, sum, 1, &sum, 1, vDSP_Length(sample.count))
			}
			
			vDSP_vsdiv(sum, 1, [max(Float(clusters[i].count), 1)], &sum, 1, vDSP_Length(sum.count))
			clusterCenters[i] = sum
		}
		
		return !zip(clusterCenters, currentCenters).map{$0.0 == $0.1}.reduce(true, {$0 && $1})
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
