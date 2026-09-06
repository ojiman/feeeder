// Connect only to the two synthetic listeners provided by the coordinator.
// Mach lookup obtains a service port only; never queries any credential/item.
#include <arpa/inet.h>
#include <errno.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>

static void connect_probe(const char *role, const char *name, int family,
                          const struct sockaddr *address, socklen_t length) {
    errno = 0;
    int fd = socket(family, SOCK_STREAM, 0);
    int connected = 0, sent = 0, error = errno;
    if (fd >= 0) {
        struct timeval timeout = {1, 0};
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
        connected = connect(fd, address, length) == 0;
        error = connected ? 0 : errno;
        if (connected) {
            sent = send(fd, "x", 1, 0) == 1;
            if (!sent) error = errno;
        }
        close(fd);
    }
    printf("{\"role\":\"%s\",\"transport\":\"%s\",\"connect\":%s,\"sent\":%s,\"errno\":%d}\n",
           role, name, connected ? "true" : "false", sent ? "true" : "false", error);
}

static void lookup_probe(const char *role, const char *service) {
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t result = bootstrap_look_up(bootstrap_port, service, &port);
    printf("{\"role\":\"%s\",\"service\":\"%s\",\"lookup_status\":%d}\n", role, service, result);
    if (result == KERN_SUCCESS && port != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), port);
    }
}

int main(int argc, char **argv) {
    if (argc != 3 && argc != 4) return 2;
    const char *role = argc == 3 ? "parent" : "child";
    long port = strtol(argv[1], NULL, 10);
    struct sockaddr_un local = {0};
    if (port < 1 || port > 65535 || strlen(argv[2]) >= sizeof(local.sun_path)) return 3;
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_port = htons((uint16_t)port);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    connect_probe(role, "loopback", AF_INET, (const struct sockaddr *)&address, sizeof(address));
    local.sun_family = AF_UNIX;
    strcpy(local.sun_path, argv[2]);
    connect_probe(role, "unix", AF_UNIX, (const struct sockaddr *)&local, sizeof(local));
    // Name from /System/Library/LaunchDaemons/com.apple.securityd.plist MachServices.
    lookup_probe(role, "com.apple.SecurityServer");
    lookup_probe(role, "com.apple.pasteboard.1");
    fflush(stdout);
    if (argc == 3) {
        pid_t child = fork();
        if (child < 0) return 4;
        if (child == 0) {
            execl(argv[0], argv[0], argv[1], argv[2], "child", (char *)NULL);
            _exit(5);
        }
        int status;
        if (waitpid(child, &status, 0) < 0) return 6;
        return WIFEXITED(status) ? WEXITSTATUS(status) : 7;
    }
    return 0;
}
