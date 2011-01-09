#import "ViAppController.h"
#import "ViThemeStore.h"
#import "ViLanguageStore.h"
#import "ViDocument.h"
#import "ViDocumentController.h"
#import "ViPreferencesController.h"

@implementation ViAppController

@synthesize lastSearchPattern;
@synthesize encodingMenu;

- (id)init
{
	self = [super init];
	if (self) {
		[NSApp setDelegate:self];
		sharedBuffers = [[NSMutableDictionary alloc] init];
	}
	return self;
}

// Application Delegate method
// stops the application from creating an untitled document on load
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return YES;
}

- (void)newBundleLoaded:(NSNotification *)notification
{
	/* Check if any open documents got a better language available. */
	ViDocument *doc;
	for (doc in [[NSDocumentController sharedDocumentController] documents])
		if ([doc respondsToSelector:@selector(configureSyntax)])
			[doc configureSyntax];
}

+ (NSString *)supportDirectory
{
	static NSString *supportDirectory = nil;
	if (supportDirectory == nil)
		supportDirectory = [@"~/Library/Application Support/Vibrant" stringByExpandingTildeInPath];
	return supportDirectory;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	[[NSFileManager defaultManager] createDirectoryAtPath:[ViAppController supportDirectory]
				  withIntermediateDirectories:YES
						   attributes:nil
							error:nil];

	/* initialize default defaults */
	[[NSUserDefaults standardUserDefaults] registerDefaults:
		[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:8], @"shiftwidth",
			[NSNumber numberWithInt:8], @"tabstop",
			[NSNumber numberWithBool:YES], @"autoindent",
			[NSNumber numberWithBool:YES], @"ignorecase",
			[NSNumber numberWithBool:NO], @"expandtabs",
			[NSNumber numberWithBool:YES], @"number",
			[NSNumber numberWithBool:YES], @"autocollapse",
			[NSNumber numberWithBool:NO], @"hidetab",
			[NSNumber numberWithBool:YES], @"searchincr",
			[NSNumber numberWithBool:NO], @"showguide",
			[NSNumber numberWithBool:NO], @"wrap",
			[NSNumber numberWithBool:YES], @"antialias",
			[NSNumber numberWithInt:80], @"guidecolumn",
			[NSNumber numberWithFloat:11.0], @"fontsize",
			@"Menlo Regular", @"fontname",
			@"Mac Classic", @"theme",
			@"(CVS|_darcs|.svn|.git|~$|\\.bak$|\\.o$)", @"skipPattern",
			[NSArray arrayWithObject:[NSDictionary dictionaryWithObject:@"textmate" forKey:@"username"]], @"bundleRepositoryUsers",
			nil]];

	/* Initialize languages and themes. */
	[ViLanguageStore defaultStore];
	[ViThemeStore defaultStore];

	[[commandMenu supermenu] removeItemAtIndex:4];
#if 0
	/* initialize commands */
	NSArray *bundles = [[ViLanguageStore defaultStore] allBundles];
	ViBundle *bundle;
	for (bundle in bundles) {
		NSMenuItem *item = [commandMenu addItemWithTitle:[bundle name] action:nil keyEquivalent:@""];
		NSMenu *submenu = [[NSMenu alloc] initWithTitle:[bundle name]];
		[item setSubmenu:submenu];
		NSDictionary *command;
		for (command in [bundle commands]) {
			NSString *key = [command objectForKey:@"keyEquivalent"];
			NSString *keyEquiv = @"";
			NSUInteger modMask = 0;
			int i;
			for (i = 0; i < [key length]; i++) {
				unichar c = [key characterAtIndex:i];
				switch (c)
				{
				case '^':
					modMask |= NSControlKeyMask;
					break;
				case '@':
					modMask |= NSCommandKeyMask;
					break;
				case '~':
					modMask |= NSAlternateKeyMask;
					break;
				default:
					keyEquiv = [NSString stringWithFormat:@"%C", c];
					break;
				}
			}

			NSMenuItem *subitem = [submenu addItemWithTitle:[command objectForKey:@"name"]
								 action:@selector(performBundleCommand:)
							  keyEquivalent:keyEquiv];
			[subitem setKeyEquivalentModifierMask:modMask];
			[subitem setRepresentedObject:command];
		}
	}
#endif

	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"theme"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"showguide"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"guidecolumn"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(newBundleLoaded:)
						     name:ViLanguageStoreBundleLoadedNotification object:nil];

	const NSStringEncoding *encoding = [NSString availableStringEncodings];
	NSMutableArray *array = [NSMutableArray array];
	NSMenuItem *item;
	while (*encoding) {
		item = [[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:*encoding]
						  action:@selector(setEncoding:)
					   keyEquivalent:@""];
		[item setRepresentedObject:[NSNumber numberWithUnsignedLong:*encoding]];
		[array addObject:item];
		encoding++;
	}

	NSSortDescriptor *sdesc = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
	[array sortUsingDescriptors:[NSArray arrayWithObject:sdesc]];
	for (item in array)
		[encodingMenu addItem:item];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context

{
	ViDocument *doc;

	if ([keyPath isEqualToString:@"theme"]) {
		for (doc in [[NSDocumentController sharedDocumentController] documents])
			if ([doc respondsToSelector:@selector(changeTheme:)])
				[doc changeTheme:[[ViThemeStore defaultStore] themeWithName:[change objectForKey:NSKeyValueChangeNewKey]]];
	} else if ([keyPath isEqualToString:@"showguide"] || [keyPath isEqualToString:@"guidecolumn"]) {
		for (doc in [[NSDocumentController sharedDocumentController] documents])
			if ([doc respondsToSelector:@selector(updatePageGuide)])
				[doc updatePageGuide];
	}
}

- (IBAction)showPreferences:(id)sender
{
	[[ViPreferencesController sharedPreferences] show];
}

- (NSMutableDictionary *)sharedBuffers
{
	return sharedBuffers;
}

extern BOOL makeNewWindowInsteadOfTab;

- (IBAction)newProject:(id)sender
{
	NSError *error = nil;
	NSDocument *proj = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"Project" error:&error];
	if (proj) {
		[[NSDocumentController sharedDocumentController] addDocument:proj];
		[proj makeWindowControllers];
		[proj showWindows];
	}
	else {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
	}
}

@end

