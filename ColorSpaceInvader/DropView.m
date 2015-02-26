//
//  DropView.m
//  ColorSpaceInvader
//
//  Created by Casey Fleser on 2/25/15.
//  Copyright (c) 2015 Quiet Spark. All rights reserved.
//

#import "DropView.h"
#import "ColorSpacerScanner.h"


@interface DropView()

@property (nonatomic, weak) IBOutlet ColorSpacerScanner	*scanner;
@property (nonatomic, assign) BOOL						highlighted;

@end


@implementation DropView

- (void) awakeFromNib
{
    [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
}

- (NSArray *) pathsInPasteboard: (NSPasteboard *) inPasteboard
{
	NSMutableArray		*paths = [NSMutableArray array];
	
    if ([[inPasteboard types] containsObject: NSFilenamesPboardType]) {
		NSWorkspace		*workspace = [NSWorkspace sharedWorkspace];
		
        for (NSString *path in [inPasteboard propertyListForType: NSFilenamesPboardType]) {
            NSError		*error = nil;
            NSString	*utiType = [workspace typeOfFile: path error: &error];
			
            if ([workspace type: utiType conformsToType: (id)kUTTypeFolder]) {
				[paths addObject: path];
            }
        }
    }

	return paths;
}

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>) inSender
{
	NSArray				*dirPaths = [self pathsInPasteboard: [inSender draggingPasteboard]];
	
	self.highlighted = [dirPaths count];
	return self.highlighted ? NSDragOperationEvery : NSDragOperationNone;
}

- (void) draggingExited: (id <NSDraggingInfo>) inSender
{
	self.highlighted = NO;
}

- (BOOL) prepareForDragOperation: (id <NSDraggingInfo>) inSender
{
    return YES;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>) inSender
{
	[self.scanner scanForCandidatesInPaths: [self pathsInPasteboard: [inSender draggingPasteboard]]];
	self.highlighted = NO;
	
    return YES;
}

- (void) setHighlighted :(BOOL) inHighlighted
{
	_highlighted = inHighlighted;
	
    [self setNeedsDisplay:YES];
}

- (void) drawRect: (NSRect) inRect {
    [super drawRect: inRect];
	
    if (self.highlighted) {
        [NSBezierPath setDefaultLineWidth: 6.0];
        [[NSColor keyboardFocusIndicatorColor] set];
        [NSBezierPath strokeRect: self.frame];
    }
}


@end
