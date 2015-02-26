//
//  ColorSpacerScanner.m
//  ColorSpaceInvader
//
//  Created by Casey Fleser on 2/25/15.
//  Copyright (c) 2015 Quiet Spark. All rights reserved.
//

#import "ColorSpacerScanner.h"
#import <Cocoa/Cocoa.h>


@interface ColorSpacerScanner ()

@property (nonatomic, strong) IBOutlet NSTextView		*outputView;

@end


@implementation ColorSpacerScanner

+ (NSDictionary *) normalOutputAttributes
{
	static NSDictionary *sOutputAttributes = nil;
	
	if (sOutputAttributes == nil) {
		sOutputAttributes = @{
			NSFontAttributeName : [NSFont fontWithName: @"Monaco" size: 9.0],
			NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0]
		};
	}
	
	return sOutputAttributes;
}

+ (NSDictionary *) highlightedOutputAttributes
{
	static NSDictionary *sHighlitedOutputAttributes = nil;
	
	if (sHighlitedOutputAttributes == nil) {
		sHighlitedOutputAttributes = @{
			NSFontAttributeName : [NSFont fontWithName: @"Monaco" size: 9.0],
			NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed: 0.66 green: 0.0 blue: 0.0 alpha: 1.0]
		};
	}
	
	return sHighlitedOutputAttributes;
}

- (void) scanForCandidatesInPaths: (NSArray *) inPaths
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSFileManager		*fileManager = [NSFileManager defaultManager];
		
		for (NSString *dirPath in inPaths) {
			NSDirectoryEnumerator	*dirEnum = [fileManager enumeratorAtPath: dirPath];
			NSString				*filePath;
			
			while ((filePath = [dirEnum nextObject])) {
				if ([[filePath pathExtension] isEqualToString: @"storyboard"]) {
					[self scanStoryboardOrXIBAtPath: [dirPath stringByAppendingPathComponent: filePath]];
				}
				else if ([[filePath pathExtension] isEqualToString: @"xib"]) {
					[self scanStoryboardOrXIBAtPath: [dirPath stringByAppendingPathComponent: filePath]];
				}
			}
		}
	});
}

- (void) scanStoryboardOrXIBAtPath: (NSString *) inPath
{
	NSURL		*storyboardURL = [NSURL URLWithString: [NSString stringWithFormat: @"file://%@", inPath]];
	
	if (storyboardURL != nil) {
		NSError			*xmlError;
		NSXMLDocument	*xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL: storyboardURL options: NSXMLDocumentXMLKind error: &xmlError];
	
		if (xmlDoc != nil) {
			NSArray		*colors = [xmlDoc nodesForXPath: @".//color" error: &xmlError];
			NSInteger	fixCount = 0;

			[self appendToOutput: [NSString stringWithFormat: @"Scanning: %@\n", [inPath lastPathComponent]] andHighlight: NO];

			for (NSXMLElement *node in colors) {
				if ([node isKindOfClass: [NSXMLElement class]]) {
					NSXMLNode	*colorSpaceAttr = [node attributeForName: @"colorSpace"];
					BOOL		shouldFix = NO;
					
					if (colorSpaceAttr != nil) {
						if ([[colorSpaceAttr stringValue] rangeOfString: @"calibrated"].location == NSNotFound) {
							NSXMLNode	*customColorSpaceAttr = [node attributeForName: @"customColorSpace"];

							if (customColorSpaceAttr != nil) {
								if ([[customColorSpaceAttr stringValue] rangeOfString: @"calibrated"].location == NSNotFound) {
									shouldFix = YES;
								}
							}
							else {
								shouldFix = YES;
							}
						}
					}
					
					if (shouldFix) {
						if ([self correctColorSpaceWithElement: node]) {
							fixCount++;
						}
					}
				}
			}
			
			if (fixCount) {
				NSMutableData	*xmlData;
				
				xmlData = [[xmlDoc XMLDataWithOptions: NSXMLNodePrettyPrint | NSXMLNodeCompactEmptyElement] mutableCopy];
				[xmlData appendData: [@"\n" dataUsingEncoding: NSUTF8StringEncoding]];
				if (![xmlData writeToFile: inPath atomically: YES]) {
					[self appendToOutput: [NSString stringWithFormat: @"Could write corrections to %@\n", [inPath lastPathComponent]] andHighlight: YES];
				}
				else {
					[self appendToOutput: [NSString stringWithFormat: @"Corrected %d color entries\n", (int)fixCount] andHighlight: YES];
				}
			}
		}
		else {
			[self appendToOutput: [NSString stringWithFormat: @"Could not scan %@ - %@\n", [inPath lastPathComponent], xmlError] andHighlight: YES];
		}
	}
	
}

- (BOOL) correctColorSpaceWithElement: (NSXMLElement *) inColorElement
{
	BOOL		didCorrect = NO;
	BOOL		hasRGBKeys = YES;
	
	for (NSString *key in @[ @"red", @"green", @"blue"]) {
		if ([inColorElement attributeForName: key] == nil) {
			hasRGBKeys = NO;
			break;
		}
	}
	
	// Is it a safe assumption to make that having a red, green, and blue value means we can just set the
	// color space to calibratedRGB? Hope so, but if not that's what SCM is for.

	if (hasRGBKeys) {
		NSXMLNode	*colorSpaceAttr = [inColorElement attributeForName: @"colorSpace"];
		
		if (colorSpaceAttr != nil) {
			[colorSpaceAttr setStringValue: @"calibratedRGB"];
			[inColorElement removeAttributeForName: @"customColorSpace"];
			didCorrect = YES;
		}
	}
	
	return didCorrect;
}

- (void) appendToOutput: (NSString *) inText
	andHighlight: (BOOL) inHighlight
{
	dispatch_async(dispatch_get_main_queue(), ^{
		NSAttributedString	*attrText = [[NSAttributedString alloc] initWithString: inText attributes: inHighlight ? [ColorSpacerScanner highlightedOutputAttributes] : [ColorSpacerScanner normalOutputAttributes]];

		[[self.outputView textStorage] appendAttributedString: attrText];
		[self.outputView scrollRangeToVisible: NSMakeRange([[self.outputView string] length], 0)];
	});
}

@end
