/*
 * SafariTechnologyPreview.h
 */

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>


@class SafariTechnologyPreviewApplication, SafariTechnologyPreviewDocument, SafariTechnologyPreviewWindow, SafariTechnologyPreviewTab, SafariTechnologyPreviewSourceProvider, SafariTechnologyPreviewContentsProvider;

enum SafariTechnologyPreviewSaveOptions {
	SafariTechnologyPreviewSaveOptionsYes = 'yes ' /* Save the file. */,
	SafariTechnologyPreviewSaveOptionsNo = 'no  ' /* Do not save the file. */,
	SafariTechnologyPreviewSaveOptionsAsk = 'ask ' /* Ask the user whether or not to save the file. */
};
typedef enum SafariTechnologyPreviewSaveOptions SafariTechnologyPreviewSaveOptions;

enum SafariTechnologyPreviewPrintingErrorHandling {
	SafariTechnologyPreviewPrintingErrorHandlingStandard = 'lwst' /* Standard PostScript error handling */,
	SafariTechnologyPreviewPrintingErrorHandlingDetailed = 'lwdt' /* print a detailed report of PostScript errors */
};
typedef enum SafariTechnologyPreviewPrintingErrorHandling SafariTechnologyPreviewPrintingErrorHandling;

@protocol SafariTechnologyPreviewGenericMethods

- (void) closeSaving:(SafariTechnologyPreviewSaveOptions)saving savingIn:(NSURL *)savingIn;  // Close a document.
- (void) saveIn:(NSURL *)in_ as:(id)as;  // Save a document.
- (void) printWithProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog;  // Print a document.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy an object.
- (void) moveTo:(SBObject *)to;  // Move an object to a new location.

@end



/*
 * Standard Suite
 */

// The application's top-level scripting object.
@interface SafariTechnologyPreviewApplication : SBApplication

- (SBElementArray<SafariTechnologyPreviewDocument *> *) documents;
- (SBElementArray<SafariTechnologyPreviewWindow *> *) windows;

@property (copy, readonly) NSString *name;  // The name of the application.
@property (readonly) BOOL frontmost;  // Is this the active application?
@property (copy, readonly) NSString *version;  // The version number of the application.

- (id) open:(id)x;  // Open a document.
- (void) print:(id)x withProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog;  // Print a document.
- (void) quitSaving:(SafariTechnologyPreviewSaveOptions)saving;  // Quit the application.
- (BOOL) exists:(id)x;  // Verify that an object exists.
- (void) addReadingListItem:(NSString *)x andPreviewText:(NSString *)andPreviewText withTitle:(NSString *)withTitle;  // Add a new Reading List item with the given URL. Allows a custom title and preview text to be specified.
- (id) doJavaScript:(NSString *)x in:(id)in_;  // Applies a string of JavaScript code to a document.
- (void) emailContentsOf:(id)of;  // Emails the contents of a tab.
- (void) searchTheWebIn:(id)in_ for:(NSString *)for_;  // Searches the web using Safari's current search provider.
- (void) showBookmarks;  // Shows Safari's bookmarks.

@end

// A document.
@interface SafariTechnologyPreviewDocument : SBObject <SafariTechnologyPreviewGenericMethods>

@property (copy, readonly) NSString *name;  // Its name.
@property (readonly) BOOL modified;  // Has it been modified since the last save?
@property (copy, readonly) NSURL *file;  // Its location on disk, if it has one.


@end

// A window.
@interface SafariTechnologyPreviewWindow : SBObject <SafariTechnologyPreviewGenericMethods>

@property (copy, readonly) NSString *name;  // The title of the window.
- (NSInteger) id;  // The unique identifier of the window.
@property NSInteger index;  // The index of the window, ordered front to back.
@property NSRect bounds;  // The bounding rectangle of the window.
@property (readonly) BOOL closeable;  // Does the window have a close button?
@property (readonly) BOOL miniaturizable;  // Does the window have a minimize button?
@property BOOL miniaturized;  // Is the window minimized right now?
@property (readonly) BOOL resizable;  // Can the window be resized?
@property BOOL visible;  // Is the window visible right now?
@property (readonly) BOOL zoomable;  // Does the window have a zoom button?
@property BOOL zoomed;  // Is the window zoomed right now?
@property (copy, readonly) SafariTechnologyPreviewDocument *document;  // The document whose contents are displayed in the window.


@end



/*
 * Safari suite
 */

// A Safari window.
@interface SafariTechnologyPreviewWindow (SafariSuite)

- (SBElementArray<SafariTechnologyPreviewTab *> *) tabs;

@property (copy) SafariTechnologyPreviewTab *currentTab;  // The current tab.

@end

// A Safari document representing the active tab in a window.
@interface SafariTechnologyPreviewDocument (SafariSuite)

@property (copy, readonly) NSString *source;  // The HTML source of the web page currently loaded in the document.
@property (copy) NSString *URL;  // The current URL of the document.
@property (copy, readonly) NSString *text;  // The text of the web page currently loaded in the document. Modifications to text aren't reflected on the web page.

@end

// A Safari window tab.
@interface SafariTechnologyPreviewTab : SBObject <SafariTechnologyPreviewGenericMethods>

@property (copy, readonly) NSString *source;  // The HTML source of the web page currently loaded in the tab.
@property (copy) NSString *URL;  // The current URL of the tab.
@property (copy, readonly) NSNumber *index;  // The index of the tab, ordered left to right.
@property (copy, readonly) NSString *text;  // The text of the web page currently loaded in the tab. Modifications to text aren't reflected on the web page.
@property (readonly) BOOL visible;  // Whether the tab is currently visible.
@property (copy, readonly) NSString *name;  // The name of the tab.


@end

