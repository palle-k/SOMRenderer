//
//  GenomeParser.swift
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


import Foundation
import Progress


struct GenomeParser
{
	private init(){}
	
	static func parseTags(at url: URL) throws -> [Int: String]
	{
		let contents = try String(contentsOf: url)
		
		let lines = Array(contents.components(separatedBy: .newlines).filter{!$0.isEmpty}.dropFirst())
		
		let tags = lines.map { line -> (Int, String) in
			let columns = line.components(separatedBy: ",")
			return (Int(columns[0])! - 1, columns[1])
		}
		
		var dict: [Int: String] = [:]
		
		for (id, name) in tags
		{
			dict[id] = name
		}
		
		return dict
	}
	
	static func parseScores(at url: URL) throws -> [(movie: Int, tag: Int, score: Float)]
	{
		let contents = try String(contentsOf: url)
		
		let lines = contents.components(separatedBy: .newlines).lazy.filter{!$0.isEmpty}.dropFirst()
		
		let scores = lines.map { line -> (Int, Int, Float) in
			let columns = line.components(separatedBy: ",")
			return (Int(columns[0])! - 1, Int(columns[1])! - 1, Float(columns[2])!)
		}
		
		return scores
	}
	
	static func parseMovies(at url: URL) throws -> [Int: String]
	{
		let contents = try String(contentsOf: url)
		
		let lines = Array(contents.components(separatedBy: .newlines).filter{!$0.isEmpty}.dropFirst())
		
		let tags = lines.map { line -> (Int, String) in
			let columns = line.components(separatedBy: ",")
			return (Int(columns[0])! - 1, Array(columns[1..<(columns.endIndex-1)]).joined(separator: ","))
		}
		
		var dict: [Int: String] = [:]
		
		for (id, name) in tags
		{
			dict[id] = name
		}
		
		return dict
	}
	
	static func joinScoresAndMovies(scores: [(movie: Int, tag: Int, score: Float)], movieNames: [Int: String]) -> [(String, Sample)]
	{
		return movieNames.flatMap { (id, name) -> (String, Sample)? in
			let movieScores = scores.filter { (movieID, _, _) in
				return movieID == id
			}
			.map { (_, _, score) -> Float in
				return score
			}
			
			guard !movieScores.isEmpty else { return nil }
			
			return (name, movieScores)
		}
	}
	
	static func parseMovieVectors(at url: URL) throws -> [(String, Sample)]
	{
		let contents = try String(contentsOf: url)
		
		let lines = contents.components(separatedBy: .newlines).filter{!$0.isEmpty}
		
		return Progress(lines).map { line -> (String, Sample) in
			
			let usesQuotationMarks = line.contains("\"")
			
			let title: String
			let sample: Sample
			
			if usesQuotationMarks, let start = line.range(of: "\"")?.upperBound, let end = line.range(of: "\"", options: String.CompareOptions.backwards)?.lowerBound
			{
				title = line.substring(with: start ..< end)
				let columns = line.substring(from: line.index(end, offsetBy: 2)).components(separatedBy: ",")
				sample = columns.map{Float($0)!}
			}
			else
			{
				let columns = line.components(separatedBy: ",").filter{!$0.isEmpty}
				title = columns[0]
				sample = columns.dropFirst().map{Float($0)!}
			}
			
			return (title, sample)
		}
	}
}
