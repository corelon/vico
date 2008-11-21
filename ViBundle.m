#import "NSString-scopeSelector.h"
#import "ViBundle.h"
#import "logging.h"

@implementation ViBundle

@synthesize languages;
@synthesize commands;
@synthesize path;

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if (self)
	{
		languages = [[NSMutableArray alloc] init];
		preferences = [[NSMutableArray alloc] init];
		cachedPreferences = [[NSMutableDictionary alloc] init];
		snippets = [[NSMutableArray alloc] init];
		commands = [[NSMutableArray alloc] init];
		path = [aPath stringByDeletingLastPathComponent];
		info = [NSDictionary dictionaryWithContentsOfFile:aPath];
	}
	
	return self;
}

- (NSString *)supportPath
{
	return [path stringByAppendingPathComponent:@"Support"];
}

- (NSString *)name
{
	return [info objectForKey:@"name"];
}

- (void)addLanguage:(ViLanguage *)lang
{
	[languages addObject:lang];
}

- (void)addPreferences:(NSDictionary *)prefs
{
	[preferences addObject:prefs];
}

- (NSDictionary *)preferenceItems:(NSString *)prefsName includeAllSettings:(BOOL)includeAllSettings
{
	NSMutableDictionary *prefsForScope = [cachedPreferences objectForKey:prefsName];
	if (prefsForScope)
		return prefsForScope;

	prefsForScope = [[NSMutableDictionary alloc] init];
	[cachedPreferences setObject:prefsForScope forKey:prefsName];

	NSDictionary *prefs;
	for (prefs in preferences)
	{
		NSString *scope = [prefs objectForKey:@"scope"];
		NSDictionary *settings = [prefs objectForKey:@"settings"];
		id prefsValue = includeAllSettings ? settings : [settings objectForKey:prefsName];
		if (prefsValue)
		{
			NSString *s;
			for (s in [scope componentsSeparatedByString:@", "])
			{
				[prefsForScope setObject:prefsValue forKey:s];
			}
		}
	}

	return prefsForScope;
}

- (NSDictionary *)preferenceItems:(NSString *)prefsName
{
	return [self preferenceItems:prefsName includeAllSettings:NO];
}

- (void)addSnippet:(NSDictionary *)snippet
{
	[snippets addObject:snippet];
}

- (void)addCommand:(NSMutableDictionary *)command
{
	[command setObject:self forKey:@"bundle"];
	[commands addObject:command];
}

- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes
{
        NSDictionary *snippet;
        for (snippet in snippets)
        {
                if ([[snippet objectForKey:@"tabTrigger"] isEqualToString:name])
                {
                        // check scopes
                        NSArray *scopeSelectors = [[snippet objectForKey:@"scope"] componentsSeparatedByString:@", "];
                        NSString *scopeSelector;
                        for (scopeSelector in scopeSelectors)
                        {
                                if ([scopeSelector matchesScopes:scopes] > 0)
                                {
                                        return [snippet objectForKey:@"content"];
                                }
                        }
                }
        }
        
        return nil;
}

@end

