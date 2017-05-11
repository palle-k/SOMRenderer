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


fileprivate extension String
{
	func allOccurences(of term: String) -> [Index]
	{
		var occurences: [Index] = []
		
		while let range = self.range(of: term, range: (occurences.last.map({self.index(after: $0)}) ?? self.startIndex) ..< self.endIndex)
		{
			occurences.append(range.lowerBound)
		}
		
		return occurences
	}
}


enum GenomeParserError: Error
{
	case invalidType(actual: String, expected: String)
	case missingData(actual: String, expected: String)
}


struct GenomeParser
{
	private init(){}
	
	
	/// Parses a CSV file of tag ids and names.
	///
	/// The data needs to be in the following format:
	///
	///     id,name
	///     1,foo
	///     2,bar
	///     ...
	///
	/// The ids must be a set of adjacent numbers starting at 1.
	/// Each ID must be unique. The order of IDs is not relevant.
	/// The header is required but field names must not match.
	/// The first column is always the column of IDs, the second column
	/// is always the column of tag names.
	///
	/// - Parameter url: URL to the tags file
	/// - Returns: A dictionary of IDs and associated tag names
	/// - Throws: An error, if the data could not be read or if it is in an invalid format.
	static func parseTags(at url: URL) throws -> [Int: String]
	{
		let contents = try String(contentsOf: url)
		
		let lines = Array(contents.components(separatedBy: .newlines).filter{!$0.isEmpty}.dropFirst())
		
		let tags = try lines.map { line -> (Int, String) in
			let columns = line.components(separatedBy: ",")
			
			guard columns.count >= 2 else
			{
				throw GenomeParserError.missingData(actual: line, expected: "Expected at least two columns: ID,NAME")
			}
			
			guard let id = Int(columns[0]) else
			{
				throw GenomeParserError.invalidType(actual: columns[0], expected: "Int")
			}
			
			return (id, columns[1])
		}
		
		var dict: [Int: String] = [:]
		
		for (id, name) in tags
		{
			dict[id] = name
		}
		
		return dict
	}
	
	
	/// Parses a CSV file of scores for a set of tags and items.
	///
	/// The file needs to be in the format
	///
	///     itemID,tagID,score
	///	    1,1,3.1415
	///     1,2,13.37
	///     ...
	///
	/// The tagIDs must start at 1.
	/// The header is required but field names must not match.
	/// The first column is always the column of item IDs, the second column
	/// is always the column of tag IDs, the third column is always the column of scores.
	///
	/// - Parameter url: URL to the scores file
	/// - Returns: A collection of tuples with item keys, tag keys and associated scores.
	/// - Throws: An error if the data could not be read of if it is in an invalid format.
	static func parseScores(at url: URL) throws -> [(movie: Int, tag: Int, score: Float)]
	{
		let contents = try String(contentsOf: url)
		
		let lines = contents.components(separatedBy: .newlines).lazy.filter{!$0.isEmpty}.dropFirst()
		
		let scores = try lines.map { line -> (Int, Int, Float) in
			let columns = line.components(separatedBy: ",")
			
			guard columns.count >= 2 else
			{
				throw GenomeParserError.missingData(actual: line, expected: "At least three columns: ID,TAGID,NAME")
			}
			
			guard let movieID = Int(columns[0]) else
			{
				throw GenomeParserError.invalidType(actual: columns[0], expected: "Int")
			}
			
			guard let tagID = Int(columns[1]) else
			{
				throw GenomeParserError.invalidType(actual: columns[1], expected: "Int")
			}
			
			guard let score = Float(columns[2]) else
			{
				throw GenomeParserError.invalidType(actual: columns[3], expected: "Float")
			}
			
			return (movieID, tagID, score)
		}
		
		return scores
	}
	
	
	/// Parses a CSV file of movies.
	///
	/// The file must be in the format
	///
	///     id,name,genres
	///     1,foo,bar
	///     2,baz,fooBar
	///     ...
	///
	/// The header is required but field names must not match.
	/// The first column is always the column of IDs, the second column
	/// is always the column of item names.
	/// A third column of genres is also expected but currently ignored.
	///
	/// - Parameter url: Path to the file of movies.
	/// - Returns: A dictionary of movie IDs and their associated names
	/// - Throws: An error, if the file could not be read or if it is in an invalid format.
	static func parseMovies(at url: URL) throws -> [Int: String]
	{
		let contents = try String(contentsOf: url)
		
		let lines = Array(contents.components(separatedBy: .newlines).filter{!$0.isEmpty}.dropFirst())
		
		let tags = try lines.map { line -> (Int, String) in
			let columns = line.components(separatedBy: ",")
			
			guard columns.count >= 3 else
			{
				throw GenomeParserError.missingData(actual: line, expected: "At least three columns: ID,NAME,GENRES")
			}
			
			guard let id = Int(columns[0]) else
			{
				throw GenomeParserError.invalidType(actual: columns[0], expected: "Int")
			}
			
			return (id, Array(columns[1..<(columns.endIndex-1)]).joined(separator: ","))
		}
		
		var dict: [Int: String] = [:]
		
		for (id, name) in tags
		{
			dict[id] = name
		}
		
		return dict
	}
	
	
	/// Generates a matrix of scores from a list of item id - tag id - score tuples.
	/// This method assumes that tags are starting at 1 and every tag ID from 1 to the largest tag ID exists
	/// and tags for each item are ordered in ascending order.
	///
	/// - Parameter scores: A list of item id, tag id, score tuples
	/// - Returns: A list of item id, score vector tuples.
	static func generateGenomeScoreMatrix(from scores: [(movie: Int, tag: Int, score: Float)]) -> [(Int, [Float])]
	{
		print("Grouping scores...")
		var scoreVectors: [Int: [Float]] = [:]
		
		for (movie, tagID, score) in Progress(scores)
		{
			assert(
				(scoreVectors[movie] ?? []).count == tagID,
				"Invalid tagID (\((scoreVectors[movie] ?? []).count) expected, actual: \(tagID))"
			)
			
			scoreVectors[movie] = (scoreVectors[movie] ?? [])
			scoreVectors[movie]?.append(score)
		}
		
		return scoreVectors.sorted(by: { $0.key < $1.key })
	}
	
	
	/// Writes a CSV file consisting of rows of items.
	///
	/// - Parameters:
	///   - rows: Rows of items.
	///   - columns: Names of columns. If not specified, no header is generated.
	///   - url: Target URL to which the resulting data is written.
	/// - Throws: An error, if the data could not be written.
	static func write(_ rows: [[Any]], columns: [String]? = nil, to url: URL) throws
	{
		let csv = Progress(rows)
			.map { row -> String in
				return row.map{ "\($0)" }.joined(separator: ",")
			}
			.joined(separator: "\n")
		
		let header = columns?.joined(separator: ",")
		
		try (header?.appending("\n") ?? "")
			.appending(csv)
			.write(to: url, atomically: true, encoding: .ascii)
	}
	
	
	/// Parses a file containing ratings of items in matrix form.
	///
	/// The file must be in the following format:
	/// 
	///     itemID1,score1,...,scoreM
	///     itemID2,score1,...,scoreM
	///     ...
	///
	/// - Parameter url: URL at which the vector file is located.
	/// - Returns: A list of samples and their corresponding IDs
	/// - Throws: An error, if the file could not be written.
	static func parseMovieVectors(at url: URL) throws -> [(Int, Sample)]
	{
		let contents = try String(contentsOf: url)
		
		let lines = contents.components(separatedBy: .newlines).filter{!$0.isEmpty}
		
		return Progress(lines).map { line -> (Int, Sample) in
			let columns = line.components(separatedBy: ",").filter{!$0.isEmpty}
			
			let title = Int(columns[0])!
			let sample = columns.dropFirst().map{Float($0)!}
			
			return (title, sample)
		}
	}
	
}
