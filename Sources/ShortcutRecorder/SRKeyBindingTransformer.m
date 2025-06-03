//
//  Copyright 2019 ShortcutRecorder Contributors
//  CC BY 4.0
//

#import "ShortcutRecorder/SRKeyCodeTransformer.h"

#import "ShortcutRecorder/SRKeyBindingTransformer.h"


static os_log_t _Log;


@implementation SRKeyBindingTransformer

#pragma mark Methods

+ (instancetype)sharedTransformer
{
    static dispatch_once_t OnceToken;
    static SRKeyBindingTransformer *Transformer = nil;
    dispatch_once(&OnceToken, ^{
        Transformer = [SRKeyBindingTransformer new];
    });
    return Transformer;
}

#pragma mark NSValueTransformer

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return NSString.class;
}

- (SRShortcut *)transformedValue:(NSString *)aValue
{
    if (![aValue isKindOfClass:NSString.class] || !aValue.length)
        return nil;

    static NSCharacterSet *FlagsCharacters = nil;
    static dispatch_once_t OnceToken;
    dispatch_once(&OnceToken, ^{
        FlagsCharacters = [NSCharacterSet characterSetWithCharactersInString:@"^~$@#"];
    });

    NSScanner *parser = [NSScanner scannerWithString:aValue];
    parser.caseSensitive = NO;

    NSString *modifierFlagsString = nil;
    [parser scanCharactersFromSet:FlagsCharacters intoString:&modifierFlagsString];
    NSString *keyCodeString = [aValue substringFromIndex:parser.scanLocation];

    if (keyCodeString.length != 1)
    {
        SRLogError(_Log, "#transform unexpected key symbol \"%s\"", keyCodeString.UTF8String);
        return nil;
    }

    NSEventModifierFlags modifierFlags = 0;

    if ([modifierFlagsString containsString:@"^"])
        modifierFlags |= NSEventModifierFlagControl;

    if ([modifierFlagsString containsString:@"~"])
        modifierFlags |= NSEventModifierFlagOption;

    if ([modifierFlagsString containsString:@"$"] || ![keyCodeString.lowercaseString isEqualToString:keyCodeString])
        modifierFlags |= NSEventModifierFlagShift;

    if ([modifierFlagsString containsString:@"@"])
        modifierFlags |= NSEventModifierFlagCommand;

    keyCodeString = keyCodeString.lowercaseString;
    NSNumber *keyCode = [SRASCIISymbolicKeyCodeTransformer.sharedTransformer reverseTransformedValue:keyCodeString];

    if (!keyCode)
    {
        SRLogError(_Log, "#transform unknown key symbol \"%s\"", keyCodeString.UTF8String);
        return nil;
    }

    BOOL isNumPad = [modifierFlagsString containsString:@"#"];
    if (isNumPad)
    {
        switch (keyCode.unsignedShortValue)
        {
            case SRKeyCode0:
                keyCode = @(SRKeyCodeKeypad0);
                break;
            case SRKeyCode1:
                keyCode = @(SRKeyCodeKeypad1);
                break;
            case SRKeyCode2:
                keyCode = @(SRKeyCodeKeypad2);
                break;
            case SRKeyCode3:
                keyCode = @(SRKeyCodeKeypad3);
                break;
            case SRKeyCode4:
                keyCode = @(SRKeyCodeKeypad4);
                break;
            case SRKeyCode5:
                keyCode = @(SRKeyCodeKeypad5);
                break;
            case SRKeyCode6:
                keyCode = @(SRKeyCodeKeypad6);
                break;
            case SRKeyCode7:
                keyCode = @(SRKeyCodeKeypad7);
                break;
            case SRKeyCode8:
                keyCode = @(SRKeyCodeKeypad8);
                break;
            case SRKeyCode9:
                keyCode = @(SRKeyCodeKeypad9);
                break;
            case SRKeyCodeMinus:
                keyCode = @(SRKeyCodeKeypadMinus);
                break;
            case SRKeyCodeEqual:
                keyCode = @(SRKeyCodeKeypadEquals);
                break;
            default:
                break;
        }
    }

    NSString *characters = [SRASCIISymbolicKeyCodeTransformer.sharedTransformer transformedValue:keyCode
                                                                       withImplicitModifierFlags:@(modifierFlags)
                                                                           explicitModifierFlags:nil
                                                                                 layoutDirection:NSUserInterfaceLayoutDirectionLeftToRight];
    NSString *charactersIgnoringModifiers = [SRASCIISymbolicKeyCodeTransformer.sharedTransformer transformedValue:keyCode
                                                                                        withImplicitModifierFlags:nil
                                                                                            explicitModifierFlags:@(modifierFlags)
                                                                                                  layoutDirection:NSUserInterfaceLayoutDirectionLeftToRight];

    return [SRShortcut shortcutWithCode:keyCode.unsignedShortValue
                          modifierFlags:modifierFlags
                             characters:characters
            charactersIgnoringModifiers:charactersIgnoringModifiers];
}

- (NSString *)reverseTransformedValue:(SRShortcut *)aValue
{
    if (![aValue isKindOfClass:NSDictionary.class] && ![aValue isKindOfClass:SRShortcut.class])
    {
        SRLogError(_Log, "#reverse_transform invalid value class \"%s\"", aValue.className.UTF8String);
        return nil;
    }

    NSNumber *keyCode = aValue[SRShortcutKeyKeyCode];
    if (![keyCode isKindOfClass:NSNumber.class])
    {
        SRLogError(_Log, "#reverse_transform invalid key code class \"%s\"", keyCode.className.UTF8String);
        return nil;
    }

    NSString *keyCodeSymbol = [SRASCIISymbolicKeyCodeTransformer.sharedTransformer transformedValue:keyCode];

    if (!keyCodeSymbol)
    {
        SRLogError(_Log, "#reverse_transform unexpected key code \"%s\"", keyCode.stringValue.UTF8String);
        return nil;
    }

    NSNumber *modifierFlags = aValue[SRShortcutKeyModifierFlags];

    if (![modifierFlags isKindOfClass:NSNumber.class])
        modifierFlags = @(0);

    SRKeyCode keyCodeValue = keyCode.unsignedShortValue;
    NSEventModifierFlags modifierFlagsValue = modifierFlags.unsignedIntegerValue;

    BOOL isNumPad = NO;
    switch (keyCodeValue)
    {
        case SRKeyCodeKeypad0:
        case SRKeyCodeKeypad1:
        case SRKeyCodeKeypad2:
        case SRKeyCodeKeypad3:
        case SRKeyCodeKeypad4:
        case SRKeyCodeKeypad5:
        case SRKeyCodeKeypad6:
        case SRKeyCodeKeypad7:
        case SRKeyCodeKeypad8:
        case SRKeyCodeKeypad9:
        case SRKeyCodeKeypadDecimal:
        case SRKeyCodeKeypadMultiply:
        case SRKeyCodeKeypadPlus:
        case SRKeyCodeKeypadClear:
        case SRKeyCodeKeypadDivide:
        case SRKeyCodeKeypadEnter:
        case SRKeyCodeKeypadMinus:
        case SRKeyCodeKeypadEquals:
            isNumPad = YES;
        default:
            break;
    }

    NSMutableString *keyBinding = [NSMutableString new];

    if (modifierFlagsValue & NSEventModifierFlagControl)
        [keyBinding appendString:@"^"];

    if (modifierFlagsValue & NSEventModifierFlagOption)
        [keyBinding appendString:@"~"];

    if (modifierFlagsValue & NSEventModifierFlagShift)
        [keyBinding appendString:@"$"];

    if (modifierFlagsValue & NSEventModifierFlagCommand)
        [keyBinding appendString:@"@"];

    if (isNumPad)
        [keyBinding appendString:@"#"];

    [keyBinding appendString:keyCodeSymbol];

    return [keyBinding copy];
}

#pragma mark NSObject

+ (void)initialize
{
    static dispatch_once_t OnceToken;
    dispatch_once(&OnceToken, ^{
        _Log = os_log_create(SRLogSubsystem.UTF8String, SRLogCategoryKeyBindingTransformer.UTF8String);
    });
}

@end
