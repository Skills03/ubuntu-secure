/*
 * Ubuntu Secure - Real Syscall Interception
 *
 * This library intercepts actual Ubuntu syscalls and requires
 * multi-device consensus before allowing dangerous operations.
 *
 * Compile: gcc -shared -fPIC -o libintercept.so syscall_hook.c -ldl
 * Use: export LD_PRELOAD=./libintercept.so
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>

// Original function pointers
static int (*original_execve)(const char *pathname, char *const argv[], char *const envp[]) = NULL;
static int (*original_open)(const char *pathname, int flags) = NULL;
static FILE* (*original_fopen)(const char *pathname, const char *mode) = NULL;

// Initialize original function pointers
void init_hooks() {
    if (!original_execve) {
        original_execve = dlsym(RTLD_NEXT, "execve");
    }
    if (!original_open) {
        original_open = dlsym(RTLD_NEXT, "open");
    }
    if (!original_fopen) {
        original_fopen = dlsym(RTLD_NEXT, "fopen");
    }
}

// Communication with consensus daemon
int request_consensus(const char* operation, const char* details) {
    int sock;
    struct sockaddr_un server_addr;
    char request[1024];
    char response[256];

    // Create socket
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        fprintf(stderr, "[Ubuntu Secure] Cannot connect to consensus daemon\n");
        return 0; // Fail secure - deny operation
    }

    // Connect to consensus daemon
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sun_family = AF_UNIX;
    strcpy(server_addr.sun_path, "/tmp/ubuntu_secure_consensus");

    if (connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        fprintf(stderr, "[Ubuntu Secure] Consensus daemon not running - operation denied\n");
        close(sock);
        return 0; // Fail secure
    }

    // Send request
    snprintf(request, sizeof(request), "%s|%s", operation, details);
    send(sock, request, strlen(request), 0);

    // Get response
    int bytes = recv(sock, response, sizeof(response) - 1, 0);
    close(sock);

    if (bytes > 0) {
        response[bytes] = '\0';
        return strcmp(response, "APPROVE") == 0;
    }

    return 0; // Fail secure
}

// Check if path is system-critical
int is_system_path(const char* path) {
    return (strstr(path, "/etc/") == path ||
            strstr(path, "/usr/") == path ||
            strstr(path, "/var/") == path ||
            strstr(path, "/sys/") == path ||
            strstr(path, "/proc/") == path ||
            strstr(path, "/boot/") == path);
}

// Check if this is a dangerous sudo command
int is_dangerous_sudo(char *const argv[]) {
    if (!argv || !argv[1]) return 0;

    // Check for dangerous commands
    const char* dangerous[] = {
        "rm", "rmdir", "dd", "mkfs", "fdisk",
        "mount", "umount", "modprobe", "insmod",
        "passwd", "userdel", "usermod", NULL
    };

    for (int i = 0; dangerous[i]; i++) {
        if (strstr(argv[1], dangerous[i])) {
            return 1;
        }
    }

    return 0;
}

// Intercept execve (catches sudo and other commands)
int execve(const char *pathname, char *const argv[], char *const envp[]) {
    init_hooks();

    // Check if this is sudo
    if (pathname && (strstr(pathname, "sudo") || (argv[0] && strstr(argv[0], "sudo")))) {
        char details[1024] = {0};

        // Build command details
        if (argv && argv[1]) {
            snprintf(details, sizeof(details), "sudo %s", argv[1]);

            // Add more args if they exist
            for (int i = 2; i < 10 && argv[i]; i++) {
                strncat(details, " ", sizeof(details) - strlen(details) - 1);
                strncat(details, argv[i], sizeof(details) - strlen(details) - 1);
            }
        } else {
            strcpy(details, "sudo (interactive)");
        }

        printf("[Ubuntu Secure] Sudo request: %s\n", details);
        printf("[Ubuntu Secure] Requesting consensus from devices...\n");

        // Always require consensus for sudo
        if (!request_consensus("sudo", details)) {
            printf("[Ubuntu Secure] ❌ CONSENSUS DENIED - Sudo blocked\n");
            errno = EPERM;
            return -1;
        }

        printf("[Ubuntu Secure] ✅ CONSENSUS APPROVED - Sudo allowed\n");
    }

    // Call original execve
    return original_execve(pathname, argv, envp);
}

// Intercept open (catches file access)
int open(const char *pathname, int flags) {
    init_hooks();

    // Check if writing to system files
    if (pathname && is_system_path(pathname) && (flags & (O_WRONLY | O_RDWR | O_CREAT | O_TRUNC))) {
        printf("[Ubuntu Secure] System file write: %s\n", pathname);
        printf("[Ubuntu Secure] Requesting consensus...\n");

        if (!request_consensus("file_write", pathname)) {
            printf("[Ubuntu Secure] ❌ CONSENSUS DENIED - File write blocked\n");
            errno = EPERM;
            return -1;
        }

        printf("[Ubuntu Secure] ✅ CONSENSUS APPROVED - File write allowed\n");
    }

    return original_open(pathname, flags);
}

// Intercept fopen (catches file access via stdio)
FILE* fopen(const char *pathname, const char *mode) {
    init_hooks();

    // Check if writing to system files
    if (pathname && is_system_path(pathname) &&
        (strchr(mode, 'w') || strchr(mode, 'a') || strchr(mode, '+'))) {

        printf("[Ubuntu Secure] System file fopen: %s (mode: %s)\n", pathname, mode);
        printf("[Ubuntu Secure] Requesting consensus...\n");

        if (!request_consensus("file_write", pathname)) {
            printf("[Ubuntu Secure] ❌ CONSENSUS DENIED - File open blocked\n");
            errno = EPERM;
            return NULL;
        }

        printf("[Ubuntu Secure] ✅ CONSENSUS APPROVED - File open allowed\n");
    }

    return original_fopen(pathname, mode);
}

// Constructor - runs when library is loaded
__attribute__((constructor))
void ubuntu_secure_init() {
    printf("\n🔒 Ubuntu Secure - Real Syscall Protection Active\n");
    printf("   Your laptop is just 1 vote out of N\n");
    printf("   Dangerous operations require consensus\n\n");
    init_hooks();
}