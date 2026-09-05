// Synthetic files only. Emits outcomes and errno, never file contents/environment values.
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static void access_probe(const char *role, const char *name, const char *path, int writing) {
    errno = 0;
    int descriptor = open(path, writing ? O_WRONLY | O_CREAT | O_APPEND : O_RDONLY, 0600);
    int ok = 0;
    int error = errno;
    if (descriptor >= 0) {
        char byte;
        ok = (writing ? write(descriptor, "x", 1) : read(descriptor, &byte, 1)) == 1;
        error = ok ? 0 : errno;
        close(descriptor);
    }
    printf("%s.%s %d %d\n", role, name, ok, error);
}

int main(int argc, char **argv) {
    if (argc < 3) return 2;
    const char *role = argc > 3 ? "child" : "parent";
    const char *root = argv[1];
    char path[PATH_MAX];
#define CHECK(name, suffix, writing) do { \
    snprintf(path, sizeof(path), "%s/%s", root, suffix); \
    access_probe(role, name, path, writing); \
} while (0)
    CHECK("source_read", "source/input", 0);
    CHECK("source_write", "source/input", 1);
    CHECK("output_write", "output/generated", 1);
    errno = 0;
    int deleted = unlink(path) == 0;
    printf("%s.output_delete %d %d\n", role, deleted, deleted ? 0 : errno);
    CHECK("protected_read", "protected/canary", 0);
    CHECK("protected_write", "protected/canary", 1);
    access_probe(role, "relative_read", "../protected/canary", 0);
    CHECK("symlink_read", "source/link", 0);
    snprintf(path, sizeof(path), "%s/input", argv[2]);
    access_probe(role, "temp_read", path, 0);
    snprintf(path, sizeof(path), "%s/generated", argv[2]);
    access_probe(role, "temp_write", path, 1);
    errno = 0;
    deleted = unlink(path) == 0;
    printf("%s.temp_delete %d %d\n", role, deleted, deleted ? 0 : errno);
    printf("%s.fake_token %d 0\n", role, getenv("RSS_FAKE_TOKEN") != NULL);
    fflush(stdout);
    if (argc == 3) {
        pid_t child = fork();
        if (child < 0) return 3;
        if (child == 0) {
            execl(argv[0], argv[0], root, argv[2], "child", (char *)NULL);
            _exit(4);
        }
        int status;
        if (waitpid(child, &status, 0) < 0) return 5;
        return WIFEXITED(status) ? WEXITSTATUS(status) : 6;
    }
    return 0;
}
