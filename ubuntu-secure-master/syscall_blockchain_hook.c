/*
 * Ubuntu Secure - Blockchain Syscall Interceptor
 *
 * This library intercepts real Ubuntu syscalls and requires
 * BLOCKCHAIN CONSENSUS from Substrate validators before allowing operations.
 *
 * Architecture:
 *   Syscall → This Library → Blockchain Bridge → Substrate Validators → Consensus
 *
 * Compile: gcc -shared -fPIC -o libintercept.so syscall_blockchain_hook.c -ldl
 * Use: export LD_PRELOAD=./libintercept.so
 *
 * Requires: blockchain_bridge.py running with Substrate nodes
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
#include <time.h>
#include <fcntl.h>

// Original function pointers
static int (*original_execve)(const char *pathname, char *const argv[], char *const envp[]) = NULL;
static int (*original_open)(const char *pathname, int flags) = NULL;
static FILE* (*original_fopen)(const char *pathname, const char *mode) = NULL;

// Statistics
static int total_syscalls = 0;
static int blocked_syscalls = 0;
static int blockchain_requests = 0;

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

// Request consensus from blockchain bridge
int request_blockchain_consensus(const char* operation, const char* details) {
    int sock;
    struct sockaddr_un server_addr;
    char request[2048];
    char response[256];
    struct timeval timeout;

    blockchain_requests++;

    // Create socket with timeout
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        fprintf(stderr, "[Ubuntu Secure] Cannot create socket for blockchain bridge\n");
        return 0; // Fail secure
    }

    // Set socket timeout (blockchain operations can take time)
    timeout.tv_sec = 15;  // 15 second timeout for blockchain consensus
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    // Connect to blockchain bridge
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sun_family = AF_UNIX;
    strcpy(server_addr.sun_path, "/tmp/ubuntu_secure_consensus");

    if (connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        fprintf(stderr, "[Ubuntu Secure] Blockchain bridge not running\n");
        fprintf(stderr, "   Start with: python3 blockchain_bridge.py\n");
        fprintf(stderr, "   Requires: Substrate validators running\n");
        close(sock);
        return 0; // Fail secure
    }

    // Send request to blockchain bridge
    snprintf(request, sizeof(request), "%s|%s", operation, details);

    if (send(sock, request, strlen(request), 0) < 0) {
        fprintf(stderr, "[Ubuntu Secure] Failed to send to blockchain bridge\n");
        close(sock);
        return 0;
    }

    // Get blockchain consensus response
    int bytes = recv(sock, response, sizeof(response) - 1, 0);
    close(sock);

    if (bytes > 0) {
        response[bytes] = '\0';
        return strcmp(response, "APPROVE") == 0;
    } else if (bytes == 0) {
        fprintf(stderr, "[Ubuntu Secure] Blockchain bridge disconnected\n");
    } else {
        fprintf(stderr, "[Ubuntu Secure] Blockchain consensus timeout\n");
    }

    return 0; // Fail secure
}

// Check if operation requires blockchain consensus
int requires_consensus(const char* operation, const char* details) {
    // Always require consensus for:

    // 1. All sudo operations
    if (strcmp(operation, "sudo") == 0) {
        return 1;
    }

    // 2. System file writes
    if (strcmp(operation, "file_write") == 0) {
        if (strstr(details, "/etc/") == details ||
            strstr(details, "/usr/") == details ||
            strstr(details, "/var/") == details ||
            strstr(details, "/sys/") == details ||
            strstr(details, "/proc/") == details ||
            strstr(details, "/boot/") == details) {
            return 1;
        }
    }

    // 3. Network operations (future)
    if (strcmp(operation, "network") == 0) {
        return 1;
    }

    return 0; // No consensus needed
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

// Intercept execve (catches sudo and other commands)
int execve(const char *pathname, char *const argv[], char *const envp[]) {
    init_hooks();
    total_syscalls++;

    // Check if this is sudo
    if (pathname && (strstr(pathname, "sudo") || (argv[0] && strstr(argv[0], "sudo")))) {
        char details[1024] = {0};

        // Build detailed command
        if (argv && argv[1]) {
            snprintf(details, sizeof(details), "%s", argv[1]);

            // Add additional arguments
            for (int i = 2; i < 10 && argv[i]; i++) {
                strncat(details, " ", sizeof(details) - strlen(details) - 1);
                strncat(details, argv[i], sizeof(details) - strlen(details) - 1);
            }
        } else {
            strcpy(details, "(interactive)");
        }

        printf("\n🔒 [Ubuntu Secure] Sudo request intercepted\n");
        printf("   Command: sudo %s\n", details);
        printf("   Requesting BLOCKCHAIN CONSENSUS from Substrate validators...\n");

        // Request blockchain consensus
        if (!request_blockchain_consensus("sudo", details)) {
            printf("   ❌ BLOCKCHAIN CONSENSUS DENIED - Sudo operation blocked\n");
            printf("   Your laptop was outvoted by the validator network.\n\n");

            blocked_syscalls++;
            errno = EPERM;
            return -1;
        }

        printf("   ✅ BLOCKCHAIN CONSENSUS APPROVED - Sudo operation allowed\n");
        printf("   The validator network has spoken.\n\n");
    }

    // Call original execve
    return original_execve(pathname, argv, envp);
}

// Intercept open (catches file access)
int open(const char *pathname, int flags) {
    init_hooks();
    total_syscalls++;

    // Check if writing to system files
    if (pathname && is_system_path(pathname) &&
        (flags & (O_WRONLY | O_RDWR | O_CREAT | O_TRUNC))) {

        printf("\n🔒 [Ubuntu Secure] System file write intercepted\n");
        printf("   File: %s\n", pathname);
        printf("   Requesting BLOCKCHAIN CONSENSUS...\n");

        if (!request_blockchain_consensus("file_write", pathname)) {
            printf("   ❌ BLOCKCHAIN CONSENSUS DENIED - File write blocked\n");
            printf("   System files are protected by validator consensus.\n\n");

            blocked_syscalls++;
            errno = EPERM;
            return -1;
        }

        printf("   ✅ BLOCKCHAIN CONSENSUS APPROVED - File write allowed\n\n");
    }

    return original_open(pathname, flags);
}

// Intercept fopen (catches file access via stdio)
FILE* fopen(const char *pathname, const char *mode) {
    init_hooks();
    total_syscalls++;

    // Check if writing to system files
    if (pathname && is_system_path(pathname) &&
        (strchr(mode, 'w') || strchr(mode, 'a') || strchr(mode, '+'))) {

        printf("\n🔒 [Ubuntu Secure] System file fopen intercepted\n");
        printf("   File: %s (mode: %s)\n", pathname, mode);
        printf("   Requesting BLOCKCHAIN CONSENSUS...\n");

        if (!request_blockchain_consensus("file_write", pathname)) {
            printf("   ❌ BLOCKCHAIN CONSENSUS DENIED - File open blocked\n");
            printf("   System files require validator approval.\n\n");

            blocked_syscalls++;
            errno = EPERM;
            return NULL;
        }

        printf("   ✅ BLOCKCHAIN CONSENSUS APPROVED - File open allowed\n\n");
    }

    return original_fopen(pathname, mode);
}

// Print statistics on exit
void print_protection_stats() {
    if (total_syscalls > 0 || blockchain_requests > 0) {
        printf("\n🔒 Ubuntu Secure Protection Statistics:\n");
        printf("   Total syscalls intercepted: %d\n", total_syscalls);
        printf("   Blockchain consensus requests: %d\n", blockchain_requests);
        printf("   Operations blocked: %d\n", blocked_syscalls);

        if (blockchain_requests > 0) {
            float block_rate = (float)blocked_syscalls / blockchain_requests * 100;
            printf("   Protection rate: %.1f%%\n", block_rate);
        }

        printf("   Your Ubuntu was protected by blockchain consensus.\n");
        printf("   Your laptop was just 1 validator out of N.\n");
    }
}

// Constructor - runs when library is loaded
__attribute__((constructor))
void ubuntu_secure_init() {
    printf("\n🔗 Ubuntu Secure - Blockchain Syscall Protection Active\n");
    printf("======================================================\n");
    printf("   Your syscalls are now protected by Substrate blockchain\n");
    printf("   Dangerous operations require validator consensus\n");
    printf("   Your laptop is just 1 vote out of N\n\n");

    // Register cleanup function
    atexit(print_protection_stats);

    init_hooks();
}

// Destructor - runs when library is unloaded
__attribute__((destructor))
void ubuntu_secure_cleanup() {
    printf("\n🔗 Ubuntu Secure - Blockchain Protection Deactivated\n");
}