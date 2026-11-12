/*
 * Synthetic 4D engine host for the Address Book ownership harness.
 *
 * Links the unchanged bundled 4D plugin SDK, its wrapper classes and the
 * plugin's 4DPlugin.cpp/dispatcher. AddressBook and Contacts are replaced by
 * deny-by-default stubs; no real Contacts data, TCC prompt, network, UI or
 * process is ever touched. Every engine owner (unistring, picture, handle) is
 * tracked so leaks and invalid/double disposal are reported by name.
 *
 * Usage: ownership_host <case>   (one case per isolated process)
 */
#include "4DPluginAPI.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"
#include "4DPlugin.h"

#include <objc/runtime.h>
#include <mach-o/dyld.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <vector>

@class ABListener;
namespace AB {
extern ABListener *listener;
extern C_TEXT LISTENER_METHOD;
extern process_number_t METHOD_PROCESS_ID;
}

typedef std::basic_string<PA_Unichar> U16;

static void deny(const char *what)
{
    fprintf(stderr, "DENY %s\n", what);
    fflush(stderr);
    abort();
}

// ---------------------------------------------------------------- engine state

struct Host {
    bool nullEmpty = false;          // engine represents "" as fString == NULL
    PA_long32 methodId = 123;        // 0 selects the EXECUTE METHOD (1007) fallback
    int resultKind = 0;              // 0 undefined, 1 text, 2 picture
    std::string failure = "none";    // none | command | handle
    bool armHandleFailure = false;
    U16 expectedMethod;
    U16 processName;
    int aliveIterations = 1;
    int dyingCalls = 0;

    std::map<PA_Unichar *, U16> strings;
    std::set<void *> pictures;
    std::map<PA_Handle, size_t> handles;

    std::vector<std::vector<U16> > calls;
    std::vector<U16> methodLookups;
    int newProcess = 0, runInMain = 0, kills = 0, sleeps = 0, yields = 0;
    void *newProcessProc = nullptr;
    int observersAdded = 0, observersRemoved = 0;
    std::vector<std::string> failures;
};
static Host g;

static void fail(const std::string &msg)
{
    g.failures.push_back(msg);
}

static U16 u16(const char16_t *s)
{
    U16 out;
    for (; *s; ++s) out.push_back((PA_Unichar)*s);
    return out;
}

static std::string utf8(const U16 &s)
{
    NSString *n = [[NSString alloc] initWithCharacters:(const unichar *)s.data() length:s.size()];
    std::string out = [n UTF8String] ? [n UTF8String] : "";
    [n release];
    return out;
}

static PA_Unistring makeString(const PA_Unichar *src)
{
    PA_Unistring u;
    memset(&u, 0, sizeof(u));
    size_t n = 0;
    if (src) while (src[n]) ++n;
    if (n == 0 && g.nullEmpty) return u;
    PA_Unichar *buf = (PA_Unichar *)calloc(n + 1, sizeof(PA_Unichar));
    if (n) memcpy(buf, src, n * sizeof(PA_Unichar));
    g.strings[buf] = U16(buf, n);
    u.fString = buf;
    u.fLength = (PA_long32)n;
    return u;
}

static void disposeString(PA_Unichar *p, const char *where)
{
    if (!p) return;
    auto it = g.strings.find(p);
    if (it == g.strings.end()) {
        fprintf(stderr, "VIOLATION invalid-dispose string %p in %s\n", (void *)p, where);
        fflush(stderr);
        abort();
    }
    g.strings.erase(it);
    free(p);
}

static U16 textOf(const PA_Variable &v, const char *where)
{
    if (v.fType != eVK_Unistring) {
        fail(std::string("argument kind not text in ") + where);
        return U16();
    }
    PA_Unichar *p = v.uValue.fString.fString;
    if (!p) {
        if (v.uValue.fString.fLength != 0) fail(std::string("null text with length in ") + where);
        return U16();
    }
    auto it = g.strings.find(p);
    if (it == g.strings.end()) {
        fprintf(stderr, "VIOLATION argument references non-live string in %s\n", where);
        fflush(stderr);
        abort();
    }
    if ((size_t)v.uValue.fString.fLength != it->second.size()) fail(std::string("length mismatch in ") + where);
    return it->second;
}

static void *makePicture()
{
    void *p = malloc(16);
    g.pictures.insert(p);
    return p;
}

static void clearVariable(PA_Variable *v)
{
    switch ((unsigned char)v->fType) {
        case eVK_Unistring:
            disposeString(v->uValue.fString.fString, "EX_CLEAR_VARIABLE");
            break;
        case eVK_Picture:
            if (v->uValue.fPicture) {
                if (!g.pictures.erase(v->uValue.fPicture)) {
                    fprintf(stderr, "VIOLATION invalid-dispose picture in EX_CLEAR_VARIABLE\n");
                    fflush(stderr);
                    abort();
                }
                free(v->uValue.fPicture);
            }
            break;
        case eVK_ArrayUnicode: {
            PA_Handle h = v->uValue.fArray.fData;
            if (h) {
                PA_Unistring *e = (PA_Unistring *)*h;
                for (PA_long32 i = 0; i <= v->uValue.fArray.fNbElements; ++i)
                    disposeString(e[i].fString, "EX_CLEAR_VARIABLE array element");
                if (!g.handles.erase(h)) {
                    fprintf(stderr, "VIOLATION invalid-dispose array handle\n");
                    fflush(stderr);
                    abort();
                }
                free(*h);
                delete h;
            }
            break;
        }
        case eVK_Undefined:
        case eVK_Longint:
        case eVK_Real:
            break;
        default:
            fprintf(stderr, "VIOLATION clear of unspecified variable kind %d\n", (int)(unsigned char)v->fType);
            fflush(stderr);
            abort();
    }
    v->fType = eVK_Undefined;
}

static void setResult(PA_Variable *r)
{
    if (g.failure == "command") {
        // engine reported an error: the result slot is unspecified (poisoned)
        r->fType = eVK_Unistring;
        r->uValue.fString.fString = (PA_Unichar *)(uintptr_t)0xa5a5a5a5a5a0ULL;
        r->uValue.fString.fLength = 7;
        return;
    }
    if (g.resultKind == 1) {
        r->fType = eVK_Unistring;
        r->fFiller = 0;
        r->uValue.fString = makeString((const PA_Unichar *)u"method result");
    } else if (g.resultKind == 2) {
        r->fType = eVK_Picture;
        r->fFiller = 0;
        r->uValue.fPicture = makePicture();
    }
}

static void handleManager(EngineBlock *eb)
{
    PA_Handle h = eb->fHandle;
    switch (eb->fParam1) {
        case 1: {
            size_t len = (size_t)eb->fParam2;
            if (g.armHandleFailure &&
                (len == 4 * sizeof(PA_Variable) || len == 4 * sizeof(PA_Variable *))) {
                eb->fHandle = 0;
                eb->fError = -108;
                return;
            }
            PA_Handle nh = new char *;
            *nh = (char *)calloc(len ? len : 1, 1);
            g.handles[nh] = len;
            eb->fHandle = nh;
            return;
        }
        case 2:
            if (!g.handles.erase(h)) {
                fprintf(stderr, "VIOLATION invalid-dispose handle\n");
                fflush(stderr);
                abort();
            }
            free(*h);
            delete h;
            return;
        case 3: {
            auto it = g.handles.find(h);
            if (it == g.handles.end()) deny("resize of unknown handle");
            size_t len = (size_t)eb->fParam2;
            char *p = (char *)realloc(*h, len ? len : 1);
            if (len > it->second) memset(p + it->second, 0, len - it->second);
            *h = p;
            it->second = len;
            return;
        }
        case 4: {
            auto it = g.handles.find(h);
            if (it == g.handles.end()) deny("size of unknown handle");
            eb->fParam2 = (sLONG_PTR)it->second;
            return;
        }
        case 5:
            if (!g.handles.count(h)) deny("lock of unknown handle");
            eb->fParam3 = (sLONG_PTR)*h;
            return;
        case 6:
        case 8:
            return;
        case 7:
            eb->fParam2 = 0;
            return;
        default:
            deny("handle manager subselector");
    }
}

static void engine(short sel, EngineBlock *eb)
{
    switch (sel) {
        case EX_CREATE_UNISTRING:
            eb->fUniString1 = makeString((const PA_Unichar *)eb->fHandle);
            return;
        case EX_DISPOSE_UNISTRING:
            disposeString(eb->fUniString1.fString, "EX_DISPOSE_UNISTRING");
            return;
        case EX_SET_UNISTRING:
            disposeString(eb->fUniString1.fString, "EX_SET_UNISTRING");
            eb->fUniString1 = makeString((const PA_Unichar *)eb->fHandle);
            return;
        case EX_CLEAR_VARIABLE:
            clearVariable((PA_Variable *)eb->fPtr1);
            return;
        case EX_HANDLE_MANAGER:
            handleManager(eb);
            return;
        case EX_GET_METHOD_ID:
            g.methodLookups.push_back(U16(eb->fUName));
            eb->fParam1 = g.methodId;
            eb->fError = 0;
            return;
        case EX_CALL_BY_PROCID: {
            PA_Variable *v = (PA_Variable *)*eb->fHandle;
            if (eb->fParam1 != 123) fail("EX_CALL_BY_PROCID id");
            if (v[0].fType != eVK_Undefined) fail("result slot not undefined on entry");
            if (eb->fParam2 == 3) {
                std::vector<U16> args;
                for (int i = 1; i <= 3; ++i) args.push_back(textOf(v[i], "method argument"));
                g.calls.push_back(args);
            }
            setResult(&v[0]);
            eb->fError = (g.failure == "command") ? 17 : 0;
            return;
        }
        case EX_EXECUTE_COMMAND_BY_ID: {
            if (eb->fParam1 != 1007 || eb->fParam2 != 4) fail("EX_EXECUTE_COMMAND_BY_ID id/count");
            PA_Variable **pv = (PA_Variable **)eb->fPtr1;
            if (textOf(*pv[0], "EXECUTE METHOD name") != g.expectedMethod) fail("EXECUTE METHOD name mismatch");
            std::vector<U16> args;
            for (int i = 1; i <= 3; ++i) args.push_back(textOf(*pv[i], "EXECUTE METHOD argument"));
            g.calls.push_back(args);
            setResult((PA_Variable *)eb->fPtr2);
            eb->fError = (g.failure == "command") ? 17 : 0;
            return;
        }
        case EX_GET_PROCESS_INFO:
            memset(eb->fUString, 0, sizeof(eb->fUString));
            memcpy(eb->fUString, g.processName.data(), g.processName.size() * sizeof(PA_Unichar));
            eb->fParam2 = 0;
            eb->fParam3 = 0;
            eb->fError = 0;
            return;
        case EX_CURRENT_PROCESS_NUMBER:
            eb->fParam1 = 7;
            return;
        case EX_IS_PROCESS_DYING:
            eb->fManyToOne = (++g.dyingCalls > g.aliveIterations) ? 1 : 0;
            return;
        case EX_YIELD_ABSOLUTE:
            g.yields++;
            return;
        case EX_PUT_PROCESS_TO_SLEEP:
            g.sleeps++;
            eb->fError = 0;
            return;
        case EX_NEW_PROCESS:
            g.newProcess++;
            g.newProcessProc = (void *)eb->fHandle;
            eb->fParam1 = 7;
            eb->fError = 0;
            return;
        case EX_RUN_IN_MAIN_PROCESS:
            g.runInMain++;
            ((void (*)(void *))eb->fPtr1)(eb->fPtr2);
            return;
        case EX_KILL_PROCESS:
            g.kills++;
            return;
        default: {
            char msg[64];
            snprintf(msg, sizeof(msg), "unexpected engine selector %d", (int)sel);
            deny(msg);
        }
    }
}

static pascal void engineEntry(short sel, EngineBlock *eb)
{
    engine(sel, eb);
}

// ------------------------------------------------------ platform deny stubs

extern "C" Class OwnershipDeniedClassFromString(NSString *) { deny("NSClassFromString"); return nil; }
extern "C" SecTaskRef OwnershipDeniedSecTaskCreateFromSelf(CFAllocatorRef) { deny("SecTaskCreateFromSelf"); return NULL; }
extern "C" CFTypeRef OwnershipDeniedSecTaskCopyValueForEntitlement(SecTaskRef, CFStringRef, CFErrorRef *) { deny("SecTaskCopyValueForEntitlement"); return NULL; }
CFStringRef ABCopyLocalizedPropertyOrLabel(CFStringRef) { deny("ABCopyLocalizedPropertyOrLabel"); return NULL; }

#define DENY_CLASS(cls, label) \
    @implementation cls \
    + (void)initialize { deny(label); } \
    @end

DENY_CLASS(OwnershipDeniedTask, "NSTask")
DENY_CLASS(OwnershipDeniedWorkspace, "NSWorkspace")
DENY_CLASS(OwnershipDeniedRunningApplication, "NSRunningApplication")
DENY_CLASS(OwnershipDeniedImage, "NSImage")
DENY_CLASS(OwnershipDeniedBundle, "NSBundle")
DENY_CLASS(OwnershipDeniedUUID, "NSUUID")
DENY_CLASS(ABRecord, "ABRecord")
DENY_CLASS(ABPerson, "ABPerson")
DENY_CLASS(ABGroup, "ABGroup")
DENY_CLASS(ABMultiValue, "ABMultiValue")
DENY_CLASS(ABMutableMultiValue, "ABMutableMultiValue")
DENY_CLASS(ABSearchElement, "ABSearchElement")
DENY_CLASS(CNContactStore, "CNContactStore")

@implementation ABAddressBook
+ (ABAddressBook *)sharedAddressBook
{
    static ABAddressBook *shared = nil;
    if (!shared) shared = [[ABAddressBook alloc] init];
    return shared;
}
+ (void)doesNotRecognizeSelector:(SEL)sel { deny([[NSString stringWithFormat:@"+[ABAddressBook %@]", NSStringFromSelector(sel)] UTF8String]); }
- (void)doesNotRecognizeSelector:(SEL)sel { deny([[NSString stringWithFormat:@"-[ABAddressBook %@]", NSStringFromSelector(sel)] UTF8String]); }
@end

@implementation OwnershipRecordingCenter
+ (NSNotificationCenter *)defaultCenter
{
    static OwnershipRecordingCenter *center = nil;
    if (!center) center = [[OwnershipRecordingCenter alloc] init];
    return center;
}
- (void)addObserver:(id)observer selector:(SEL)sel name:(NSNotificationName)name object:(id)object
{
    g.observersAdded++;
    if (![name isEqualToString:kABDatabaseChangedExternallyNotification]) fail("observer for unexpected notification");
    if (object != [ABAddressBook sharedAddressBook]) fail("observer for unexpected object");
    [super addObserver:observer selector:sel name:name object:object];
}
- (void)removeObserver:(id)observer
{
    g.observersRemoved++;
    [super removeObserver:observer];
}
@end

#define AB_CONST(name) NSString * const name = @"OwnershipStub." #name;
AB_CONST(kABAIMInstantProperty) AB_CONST(kABAddressCityKey) AB_CONST(kABAddressCountryCodeKey)
AB_CONST(kABAddressCountryKey) AB_CONST(kABAddressProperty) AB_CONST(kABAddressStateKey)
AB_CONST(kABAddressStreetKey) AB_CONST(kABAddressZIPKey) AB_CONST(kABBirthdayProperty)
AB_CONST(kABCalendarURIsProperty) AB_CONST(kABCreationDateProperty)
AB_CONST(kABDatabaseChangedExternallyNotification) AB_CONST(kABDeletedRecords)
AB_CONST(kABDepartmentProperty) AB_CONST(kABEmailProperty) AB_CONST(kABFirstNamePhoneticProperty)
AB_CONST(kABFirstNameProperty) AB_CONST(kABICQInstantProperty) AB_CONST(kABInsertedRecords)
AB_CONST(kABJabberInstantProperty) AB_CONST(kABJobTitleProperty) AB_CONST(kABLastNamePhoneticProperty)
AB_CONST(kABLastNameProperty) AB_CONST(kABMSNInstantProperty) AB_CONST(kABMaidenNameProperty)
AB_CONST(kABMiddleNamePhoneticProperty) AB_CONST(kABMiddleNameProperty)
AB_CONST(kABModificationDateProperty) AB_CONST(kABNicknameProperty) AB_CONST(kABNoteProperty)
AB_CONST(kABOrganizationProperty) AB_CONST(kABOtherDatesProperty) AB_CONST(kABPersonFlags)
AB_CONST(kABPhoneProperty) AB_CONST(kABRelatedNamesProperty) AB_CONST(kABSuffixProperty)
AB_CONST(kABTitleProperty) AB_CONST(kABUIDProperty) AB_CONST(kABURLsProperty)
AB_CONST(kABUpdatedRecords) AB_CONST(kABYahooInstantProperty)

// ------------------------------------------------------------- utilities

static PA_Unistring paramString;
static PackagePtr packOne(PA_Unistring *u)
{
    static void *slots[4];
    slots[0] = u;
    return (PackagePtr)slots;
}

static void initPlugin()
{
    PackInitBlock init;
    memset(&init, 0, sizeof(init));
    init.fCall4Dex = (Call4DProcPtr)engineEntry;
    void *data = nullptr;
    sLONG_PTR result = 0;
    FourDPackex(kInitPlugin, &init, &data, &result);
    if (gCall4D != (Call4DProcPtr)engineEntry) fail("FourDPackex did not install engine callback");
}

static sLONG_PTR dispatch(PA_long32 selector, PackagePtr params)
{
    sLONG_PTR result = 0;
    void *data = nullptr;
    FourDPackex(selector, params, &data, &result);
    return result;
}

static int finish(const std::string &name, bool expectBalanced = true)
{
    if (expectBalanced) {
        if (!g.strings.empty()) {
            std::string sample;
            for (auto &kv : g.strings) { sample += " \"" + utf8(kv.second) + "\""; if (sample.size() > 120) break; }
            fail("leaked strings=" + std::to_string(g.strings.size()) + sample);
        }
        if (!g.pictures.empty()) fail("leaked pictures=" + std::to_string(g.pictures.size()));
        if (!g.handles.empty()) fail("leaked handles=" + std::to_string(g.handles.size()));
    }
    if (g.failures.empty()) {
        printf("PASS %s\n", name.c_str());
        return 0;
    }
    for (auto &f : g.failures) printf("FAIL %s: %s\n", name.c_str(), f.c_str());
    return 1;
}

static std::vector<std::string> split(const std::string &s)
{
    std::vector<std::string> out;
    size_t start = 0, pos;
    while ((pos = s.find(':', start)) != std::string::npos) { out.push_back(s.substr(start, pos - start)); start = pos + 1; }
    out.push_back(s.substr(start));
    return out;
}

static NSString *ns(const char16_t *s)
{
    U16 u = u16(s);
    return [NSString stringWithCharacters:(const unichar *)u.data() length:u.size()];
}

struct Fixture {
    NSArray *ins, *upd, *del;
    U16 eIns, eUpd, eDel;
};

static Fixture fixture(const std::string &text, int which)
{
    Fixture f;
    if (text == "ascii") {
        f.ins = which ? @[ @"QRS-3:ABPerson" ] : @[ @"ABC-1:ABPerson", @"DEF-2:ABGroup" ];
        f.upd = @[ @"UPD-9:ABPerson" ];
        f.del = which ? @[ @"DEL-1:ABPerson", @"DEL-2:ABPerson" ] : @[];
        f.eIns = which ? u16(u"QRS-3:ABPerson") : u16(u"ABC-1:ABPerson\rDEF-2:ABGroup");
        f.eUpd = u16(u"UPD-9:ABPerson");
        f.eDel = which ? u16(u"DEL-1:ABPerson\rDEL-2:ABPerson") : U16();
    } else if (text == "bmp") {
        f.ins = @[ ns(u"\u00e9t\u00e9-\u65e5\u672c:ABPerson"), ns(u"\u0416:ABGroup") ];
        f.upd = which ? @[] : @[ ns(u"\u00fc\u00df:ABPerson") ];
        f.del = @[ ns(u"\u4e2d\u6587:ABPerson") ];
        f.eIns = u16(u"\u00e9t\u00e9-\u65e5\u672c:ABPerson\r\u0416:ABGroup");
        f.eUpd = which ? U16() : u16(u"\u00fc\u00df:ABPerson");
        f.eDel = u16(u"\u4e2d\u6587:ABPerson");
    } else if (text == "supplementary") {
        f.ins = @[ ns(u"\U0001F600:ABPerson") ];
        f.upd = @[ ns(u"\U00020B9F\U0001F468\u200D\U0001F469:ABPerson"), ns(u"x") ];
        f.del = which ? @[ ns(u"\U0001D11E") ] : @[];
        f.eIns = u16(u"\U0001F600:ABPerson");
        f.eUpd = u16(u"\U00020B9F\U0001F468\u200D\U0001F469:ABPerson\rx");
        f.eDel = which ? u16(u"\U0001D11E") : U16();
    } else {
        f.ins = @[];
        f.upd = @[];
        f.del = @[];
    }
    return f;
}

// ------------------------------------------------------------------ cases

// callback:<method|fallback>:<ascii|bmp|supplementary|empty>:<allocated|null>:<undefined|text|picture>:<none|command|handle>
static int runCallback(const std::string &name)
{
    std::vector<std::string> p = split(name);
    if (p.size() != 6) deny("malformed callback case");
    g.methodId = (p[1] == "method") ? 123 : 0;
    g.nullEmpty = (p[3] == "null");
    g.resultKind = (p[4] == "text") ? 1 : (p[4] == "picture") ? 2 : 0;
    g.failure = p[5];
    g.processName = u16(u"Main");
    g.expectedMethod = u16(u"AB_ON_CHANGE");

    initPlugin();

    paramString = makeString(g.expectedMethod.c_str());
    sLONG_PTR r = dispatch(36, packOne(&paramString));
    if ((PA_long32)r != 1) fail("AB Set notification method did not return 1");
    if (g.newProcess != 1 || !g.newProcessProc) fail("listener process not started");
    if (g.observersAdded != 1) fail("observer not registered once");
    if (AB::METHOD_PROCESS_ID != 7) fail("METHOD_PROCESS_ID not recorded");

    Fixture f0 = fixture(p[2], 0), f1 = fixture(p[2], 1);
    OwnershipRecordingCenter *center = (OwnershipRecordingCenter *)[OwnershipRecordingCenter defaultCenter];
    for (Fixture *f : { &f0, &f1 }) {
        [center postNotificationName:kABDatabaseChangedExternallyNotification
                              object:[ABAddressBook sharedAddressBook]
                            userInfo:@{ kABInsertedRecords: f->ins, kABUpdatedRecords: f->upd, kABDeletedRecords: f->del }];
    }

    g.armHandleFailure = (g.failure == "handle");
    ((void (*)(void))g.newProcessProc)();
    g.armHandleFailure = false;

    size_t expectedCalls = (g.failure == "handle") ? 0 : 2;
    if (g.calls.size() != expectedCalls)
        fail("callback count " + std::to_string(g.calls.size()) + " != " + std::to_string(expectedCalls));
    Fixture *fx[2] = { &f0, &f1 };
    for (size_t i = 0; i < g.calls.size() && i < 2; ++i) {
        const std::vector<U16> &a = g.calls[i];
        if (a[0] != fx[i]->eIns) fail("call " + std::to_string(i) + " inserted \"" + utf8(a[0]) + "\" != \"" + utf8(fx[i]->eIns) + "\"");
        if (a[1] != fx[i]->eUpd) fail("call " + std::to_string(i) + " updated \"" + utf8(a[1]) + "\" != \"" + utf8(fx[i]->eUpd) + "\"");
        if (a[2] != fx[i]->eDel) fail("call " + std::to_string(i) + " deleted \"" + utf8(a[2]) + "\" != \"" + utf8(fx[i]->eDel) + "\"");
    }
    if (g.methodLookups.size() != 2 || g.methodLookups[0] != g.expectedMethod) fail("method lookup by name");
    if (g.kills != 1 || g.runInMain != 2) fail("listener teardown incomplete");
    if (g.observersRemoved < 1 || AB::listener != nil) fail("listener not released");
    if (AB::METHOD_PROCESS_ID != 0) fail("METHOD_PROCESS_ID not reset");

    disposeString(paramString.fString, "harness parameter");
    return finish(name);
}

static int runGetMethod(const std::string &name)
{
    g.processName = u16(u"Main");
    initPlugin();
    U16 method = u16(u"\u65e5\u672c\U0001F600_method");
    paramString = makeString(method.c_str());
    dispatch(36, packOne(&paramString));
    PA_Unistring out = makeString((const PA_Unichar *)u"previous value");
    sLONG_PTR r = dispatch(37, packOne(&out));
    if ((PA_long32)r != 1) fail("AB Get notification method did not return 1");
    if (!out.fString || U16(out.fString, out.fLength) != method) fail("AB Get notification method text");
    // a non-exit process closing must not stop the listener
    dispatch(kCloseProcess, packOne(&paramString));
    ((void (*)(void))g.newProcessProc)();
    if (g.kills != 1 || g.calls.size() != 0 || AB::METHOD_PROCESS_ID != 0) fail("listener teardown");
    disposeString(out.fString, "harness out");
    disposeString(paramString.fString, "harness parameter");
    return finish(name);
}

static PA_Variable newTextArray(const std::vector<U16> &values)
{
    PA_Variable a = PA_CreateVariable(eVK_ArrayUnicode);
    PA_ResizeArray(&a, (PA_long32)values.size());
    for (size_t i = 0; i < values.size(); ++i) {
        PA_Unistring s = PA_CreateUnistring((PA_Unichar *)values[i].c_str());
        PA_SetStringInArray(a, (PA_long32)i + 1, &s);
    }
    return a;
}

static int runArray(const std::string &name)
{
    std::vector<std::string> p = split(name);
    g.nullEmpty = (p.size() > 2 && p[2] == "null");
    initPlugin();
    std::vector<U16> values = { u16(u"ascii"), u16(u"\u00e9\u65e5"), u16(u"\U0001F600"), U16() };
    const std::string &mode = p[1];
    if (mode == "wrapper-existing" || mode == "wrapper-undefined") {
        PA_Variable param = mode == "wrapper-existing" ? newTextArray({ u16(u"old") }) : PA_CreateVariable(eVK_Undefined);
        void *slots[1] = { &param };
        ARRAY_TEXT arr;
        arr.setSize(0);
        arr.appendUTF16String((const PA_Unichar *)u"");
        for (auto &v : values) arr.appendUTF16String(v.c_str());
        arr.toParamAtIndex((PackagePtr)slots, 1);
        if (param.fType != eVK_ArrayUnicode || param.uValue.fArray.fNbElements != (PA_long32)values.size()) fail("wrapper array shape");
        for (size_t i = 0; i < values.size(); ++i) {
            PA_Unistring e = PA_GetStringInArray(param, (PA_long32)i + 1);
            if (U16(e.fString ? e.fString : (PA_Unichar *)u"", e.fLength) != values[i]) fail("wrapper element " + std::to_string(i + 1));
        }
        ARRAY_TEXT back;
        back.fromParamAtIndex((PackagePtr)slots, 1);
        if (back.getSize() != values.size() + 1) fail("wrapper round trip size");
        PA_ClearVariable(&param);
    } else {
        PA_Variable a = newTextArray({ u16(u"one"), u16(u"two") });
        PA_Unistring s = PA_CreateUnistring((PA_Unichar *)u"candidate");
        PA_Unichar *candidate = s.fString;
        bool accepted = false;
        if (mode == "accept-index0") { PA_SetStringInArray(a, 0, &s); accepted = true; }
        else if (mode == "accept-last") { PA_SetStringInArray(a, 2, &s); accepted = true; }
        else if (mode == "reject-negative") PA_SetStringInArray(a, -1, &s);
        else if (mode == "reject-past-end") PA_SetStringInArray(a, 3, &s);
        else if (mode == "reject-null-ustr") PA_SetStringInArray(a, 1, NULL);
        else if (mode == "reject-wrong-kind") { PA_Variable w = a; w.fType = eVK_ArrayLongint; PA_SetStringInArray(w, 1, &s); }
        else if (mode == "reject-null-data") { PA_Variable w = a; w.uValue.fArray.fData = 0; PA_SetStringInArray(w, 1, &s); }
        else deny("unknown array case");
        bool live = candidate ? g.strings.count(candidate) != 0 : true;
        if (!live) fail("candidate disposed by SDK");
        if (accepted) {
            PA_Unistring e = PA_GetStringInArray(a, mode == "accept-index0" ? 0 : 2);
            if (e.fString != candidate) fail("accepted element not transferred");
            // ownership transferred: the caller must not dispose s
        } else {
            PA_DisposeUnistring(&s);
        }
        PA_ClearVariable(&a);
    }
    return finish(name);
}

static int runScalar(const std::string &name)
{
    std::vector<std::string> p = split(name);
    g.nullEmpty = (p.size() > 2 && p[2] == "null");
    initPlugin();
    U16 text = u16(u"r\u00e9sult \U0001F600");
    PA_Unistring result = makeString((const PA_Unichar *)u"");
    PA_Unistring *resultPtr = &result;
    C_TEXT t;
    t.setUTF16String(text.c_str(), (uint32_t)text.size());
    if (p[1] == "return") {
        t.setReturn((sLONG_PTR *)&resultPtr);
    } else {
        void *slots[1] = { &result };
        t.toParamAtIndex((PackagePtr)slots, 1);
    }
    if (!result.fString || U16(result.fString, result.fLength) != text) fail("C_TEXT output text");
    disposeString(result.fString, "harness result");
    return finish(name);
}

static int runPlatform(const std::string &name)
{
    for (const char *cls : { "ABAddressBook", "ABRecord", "ABPerson", "ABGroup", "ABMultiValue",
                             "ABMutableMultiValue", "ABSearchElement", "CNContactStore" }) {
        Class c = (Class)objc_getClass(cls);
        const char *image = c ? class_getImageName(c) : NULL;
        const char *tail = image ? strrchr(image, '/') : NULL;
        if (!tail || strcmp(tail, "/ownership_host") != 0) fail(std::string("class not provided by harness: ") + cls);
    }
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char *img = _dyld_get_image_name(i);
        if (strstr(img, "AddressBook.framework") || strstr(img, "Contacts.framework") || strstr(img, "ContactsPersistence"))
            fail(std::string("forbidden image loaded: ") + img);
    }
    return finish(name);
}

// Expected-failure probes. Each runs in its own process; the Python driver asserts the outcome.
static int runProbe(const std::string &name)
{
    initPlugin();
    if (name == "probe:shallow-overwrite-leak") {
        PA_Variable v = PA_CreateVariable(eVK_Unistring);   // allocated empty owner
        PA_Unistring s = PA_CreateUnistring((PA_Unichar *)u"x");
        PA_SetStringVariable(&v, &s);                        // shallow: empty owner lost
        PA_ClearVariable(&v);
        return finish(name);
    }
    if (name == "probe:alias-double-clear") {
        PA_Variable a = PA_CreateVariable(eVK_Undefined);
        PA_Unistring s = PA_CreateUnistring((PA_Unichar *)u"x");
        PA_SetStringVariable(&a, &s);
        PA_Variable b = a;
        PA_ClearVariable(&a);
        PA_ClearVariable(&b);
        return finish(name);
    }
    if (name == "probe:clear-failed-result") {
        g.failure = "command";
        PA_Variable none = PA_CreateVariable(eVK_Undefined);
        PA_Variable r = PA_ExecuteMethodByID(123, &none, 0);
        PA_ClearVariable(&r);
        return finish(name);
    }
    if (name == "probe:denied-selector") {
        [[ABAddressBook sharedAddressBook] performSelector:@selector(people)];
        return finish(name);
    }
    if (name == "probe:denied-class") {
        [ABPerson class];
        return finish(name);
    }
    if (name == "probe:denied-function") {
        ABCopyLocalizedPropertyOrLabel(CFSTR("x"));
        return finish(name);
    }
    deny("unknown probe");
    return 2;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: %s <case>\n", argv[0]);
            return 2;
        }
        std::string name = argv[1];
        setvbuf(stdout, NULL, _IONBF, 0);
        if (name.rfind("callback:", 0) == 0) return runCallback(name);
        if (name == "dispatcher:get-method") return runGetMethod(name);
        if (name.rfind("array:", 0) == 0) return runArray(name);
        if (name.rfind("scalar:", 0) == 0) return runScalar(name);
        if (name == "platform:isolation") return runPlatform(name);
        if (name.rfind("probe:", 0) == 0) return runProbe(name);
        deny("unknown case");
    }
    return 2;
}
