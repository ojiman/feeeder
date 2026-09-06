// A disposable legacy Keychain fixture, not production app credential code.
// Every operation uses an explicit Keychain reference; never fall back to login.
#include <Security/Security.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    const char *action = argv[1], *path = argv[2];
    if (strcmp(action, "create") && strcmp(action, "read") && strcmp(action, "delete")) return 2;
    SecKeychainRef keychain = NULL;
    const char *password = "rss-disposable-fixture-password";
    OSStatus status = SecKeychainSetUserInteractionAllowed(false);
    if (status != errSecSuccess) return 3;
    if (!strcmp(action, "create")) {
        const char *canary = getenv("RSS_KEYCHAIN_CANARY");
        if (!canary || !*canary) return 4;
        fprintf(stderr, "stage=create-keychain\n");
        status = SecKeychainCreate(path, (UInt32)strlen(password), password, false, NULL, &keychain);
        if (status == errSecSuccess && keychain) {
            status = SecKeychainUnlock(keychain, (UInt32)strlen(password), password, true);
            fprintf(stderr, "stage=prepare-initial-access\n");
            SecTrustedApplicationRef self = NULL, cli = NULL;
            SecAccessRef access = NULL;
            if (status == errSecSuccess) status = SecTrustedApplicationCreateFromPath(argv[0], &self);
            if (status == errSecSuccess) status = SecTrustedApplicationCreateFromPath("/usr/bin/security", &cli);
            if (status == errSecSuccess) {
                const void *values[] = {self, cli};
                CFArrayRef trusted = CFArrayCreate(NULL, values, 2, &kCFTypeArrayCallBacks);
                status = SecAccessCreate(CFSTR("RSS disposable fixture"), trusted, &access);
                CFRelease(trusted);
            }
            if (status == errSecSuccess) {
                SecKeychainAttribute attributes[] = {
                    {kSecServiceItemAttr, 19, (void *)"rss-harness-fixture"},
                    {kSecAccountItemAttr, 6, (void *)"canary"}
                };
                SecKeychainAttributeList list = {2, attributes};
                fprintf(stderr, "stage=create-item-with-initial-access\n");
                status = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &list,
                    (UInt32)strlen(canary), canary, keychain, access, NULL);
            }
            if (access) CFRelease(access);
            if (self) CFRelease(self);
            if (cli) CFRelease(cli);
            if (status != errSecSuccess) SecKeychainDelete(keychain);
        }
    } else {
        status = SecKeychainOpen(path, &keychain);
        if (status == errSecSuccess && keychain) {
            if (!strcmp(action, "delete")) {
                status = SecKeychainDelete(keychain);
            } else {
                fprintf(stderr, "stage=unlock-read-fixture\n");
                status = SecKeychainUnlock(keychain, (UInt32)strlen(password), password, true);
                UInt32 length = 0;
                void *data = NULL;
                if (status == errSecSuccess) {
                    status = SecKeychainFindGenericPassword(keychain, 19, "rss-harness-fixture",
                                                           6, "canary", &length, &data, NULL);
                }
                printf("{\"action\":\"read\",\"status\":%d,\"value_obtained\":%s}\n",
                       (int)status, status == errSecSuccess && data && length ? "true" : "false");
                if (data) SecKeychainItemFreeContent(NULL, data);
                CFRelease(keychain);
                return 0;
            }
        }
    }
    if (keychain) CFRelease(keychain);
    printf("{\"action\":\"%s\",\"status\":%d,\"value_obtained\":false}\n", action, (int)status);
    return 0;
}
