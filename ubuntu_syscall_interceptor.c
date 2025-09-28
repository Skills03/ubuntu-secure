#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <time.h>
#include <stdarg.h>
#include <curl/curl.h>
#include <json-c/json.h>

// Ubuntu Secure: Phase 2 - System Call Transaction Handler
// This intercepts real system calls and submits them to blockchain consensus

// Original system call function pointers
static int (*original_open)(const char *pathname, int flags, ...) = NULL;
static ssize_t (*original_write)(int fd, const void *buf, size_t count) = NULL;
static ssize_t (*original_read)(int fd, void *buf, size_t count) = NULL;
static int (*original_execve)(const char *filename, char *const argv[], char *const envp[]) = NULL;
static int (*original_chmod)(const char *pathname, mode_t mode) = NULL;
static int (*original_unlink)(const char *pathname) = NULL;

// Blockchain node RPC endpoint
#define BLOCKCHAIN_RPC "http://localhost:9944"
#define CONSENSUS_TIMEOUT 2 // seconds

// Transaction classification
typedef enum {
    CLASS_A_CONSENSUS,    // Security-critical: requires 3/5 consensus
    CLASS_B_CACHED,       // Performance-critical: cached consensus
    CLASS_C_LOCAL         // Non-critical: local only
} transaction_class_t;

// Response structure from blockchain
typedef struct {
    int approved;
    int votes_for;
    int votes_against;
    char reason[256];
} consensus_response_t;

// CURL response handler
struct response_data {
    char *buffer;
    size_t size;
};

static size_t write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t total_size = size * nmemb;
    struct response_data *mem = (struct response_data *)userp;

    char *ptr = realloc(mem->buffer, mem->size + total_size + 1);
    if (!ptr) return 0;

    mem->buffer = ptr;
    memcpy(&(mem->buffer[mem->size]), contents, total_size);
    mem->size += total_size;
    mem->buffer[mem->size] = 0;

    return total_size;
}

// Initialize interceptor on library load
void __attribute__((constructor)) init_interceptor() {
    // Load original functions
    original_open = dlsym(RTLD_NEXT, "open");
    original_write = dlsym(RTLD_NEXT, "write");
    original_read = dlsym(RTLD_NEXT, "read");
    original_execve = dlsym(RTLD_NEXT, "execve");
    original_chmod = dlsym(RTLD_NEXT, "chmod");
    original_unlink = dlsym(RTLD_NEXT, "unlink");

    // Initialize CURL for blockchain communication
    curl_global_init(CURL_GLOBAL_DEFAULT);

    fprintf(stderr, "╔══════════════════════════════════════════╗\n");
    fprintf(stderr, "║  Ubuntu Secure: System Call Interceptor  ║\n");
    fprintf(stderr, "║  Phase 2 - Transaction Handling Active   ║\n");
    fprintf(stderr, "║  All critical operations require consensus║\n");
    fprintf(stderr, "╚══════════════════════════════════════════╝\n");
}

void __attribute__((destructor)) cleanup_interceptor() {
    curl_global_cleanup();
}

// Determine if path is security-critical
int is_security_critical(const char *path) {
    if (!path) return 0;

    // System directories requiring consensus
    if (strstr(path, "/etc/") == path) return 1;
    if (strstr(path, "/boot/") == path) return 1;
    if (strstr(path, "/usr/") == path) return 1;
    if (strstr(path, "/bin/") == path) return 1;
    if (strstr(path, "/sbin/") == path) return 1;
    if (strstr(path, "/lib/") == path) return 1;
    if (strstr(path, "/root/") == path) return 1;
    if (strstr(path, "/.ssh/") != NULL) return 1;
    if (strstr(path, "/sys/") == path) return 1;
    if (strstr(path, "/proc/") == path) return 1;

    return 0;
}

// Submit transaction to blockchain and get consensus
consensus_response_t request_consensus(const char *syscall_type, const char *path, int flags) {
    consensus_response_t response = {0};
    CURL *curl;
    CURLcode res;

    curl = curl_easy_init();
    if (!curl) {
        response.approved = 0;
        strcpy(response.reason, "Failed to initialize CURL");
        return response;
    }

    // Create JSON-RPC request for blockchain
    json_object *request = json_object_new_object();
    json_object_object_add(request, "jsonrpc", json_object_new_string("2.0"));
    json_object_object_add(request, "method", json_object_new_string("ubuntu_secure_submitSyscall"));
    json_object_object_add(request, "id", json_object_new_int(1));

    json_object *params = json_object_new_object();
    json_object_object_add(params, "syscall_type", json_object_new_string(syscall_type));
    json_object_object_add(params, "path", json_object_new_string(path));
    json_object_object_add(params, "flags", json_object_new_int(flags));
    json_object_object_add(params, "class", json_object_new_string("CLASS_A"));
    json_object_object_add(request, "params", params);

    const char *json_str = json_object_to_json_string(request);

    // Setup CURL for RPC call
    struct response_data chunk = {0};
    curl_easy_setopt(curl, CURLOPT_URL, BLOCKCHAIN_RPC);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_str);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, CONSENSUS_TIMEOUT);

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    // Execute RPC call
    res = curl_easy_perform(curl);

    if (res == CURLE_OK && chunk.buffer) {
        // Parse response
        json_object *json_response = json_tokener_parse(chunk.buffer);
        if (json_response) {
            json_object *result;
            if (json_object_object_get_ex(json_response, "result", &result)) {
                json_object *approved_obj, *votes_for_obj, *votes_against_obj;

                if (json_object_object_get_ex(result, "approved", &approved_obj)) {
                    response.approved = json_object_get_boolean(approved_obj);
                }
                if (json_object_object_get_ex(result, "votes_for", &votes_for_obj)) {
                    response.votes_for = json_object_get_int(votes_for_obj);
                }
                if (json_object_object_get_ex(result, "votes_against", &votes_against_obj)) {
                    response.votes_against = json_object_get_int(votes_against_obj);
                }

                snprintf(response.reason, sizeof(response.reason),
                         "Consensus: %d/%d votes",
                         response.votes_for, response.votes_for + response.votes_against);
            }
            json_object_put(json_response);
        }
    } else {
        // Fallback: simulate consensus for demo
        fprintf(stderr, "\n[Ubuntu Secure] Blockchain RPC unavailable - Using fallback consensus\n");

        // Simulate voting based on security rules
        if (is_security_critical(path)) {
            response.approved = 0;
            response.votes_for = 1;
            response.votes_against = 4;
            strcpy(response.reason, "Security policy violation - critical path");
        } else {
            response.approved = 1;
            response.votes_for = 4;
            response.votes_against = 1;
            strcpy(response.reason, "Normal user operation approved");
        }
    }

    // Cleanup
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    json_object_put(request);
    if (chunk.buffer) free(chunk.buffer);

    return response;
}

// Print consensus result to user
void print_consensus_result(const char *operation, const char *path, consensus_response_t *result) {
    fprintf(stderr, "\n┌─────────────────────────────────────────┐\n");
    fprintf(stderr, "│     Ubuntu Secure: Consensus Request    │\n");
    fprintf(stderr, "├─────────────────────────────────────────┤\n");
    fprintf(stderr, "│ Operation: %-28s │\n", operation);
    fprintf(stderr, "│ Path: %-33s │\n", path);
    fprintf(stderr, "├─────────────────────────────────────────┤\n");
    fprintf(stderr, "│ Votes FOR:     %d/5                      │\n", result->votes_for);
    fprintf(stderr, "│ Votes AGAINST: %d/5                      │\n", result->votes_against);
    fprintf(stderr, "│ Result: %-31s │\n", result->approved ? "✓ APPROVED" : "✗ DENIED");
    fprintf(stderr, "└─────────────────────────────────────────┘\n\n");
}

// ==================== INTERCEPTED SYSTEM CALLS ====================

// Intercepted open() system call
int open(const char *pathname, int flags, ...) {
    mode_t mode = 0;

    // Handle variadic arguments
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }

    // Check if consensus is required
    if ((flags & (O_WRONLY | O_RDWR)) && is_security_critical(pathname)) {
        fprintf(stderr, "\n[Ubuntu Secure] Intercepted: open('%s', %d)\n", pathname, flags);

        // Request consensus from blockchain
        consensus_response_t result = request_consensus("FileOpen", pathname, flags);
        print_consensus_result("open()", pathname, &result);

        if (!result.approved) {
            fprintf(stderr, "[Ubuntu Secure] ⚠️  Operation BLOCKED by consensus\n");
            errno = EPERM;
            return -1;
        }

        fprintf(stderr, "[Ubuntu Secure] ✓ Operation APPROVED by consensus\n");
    }

    // Execute original system call
    if (flags & O_CREAT) {
        return original_open(pathname, flags, mode);
    } else {
        return original_open(pathname, flags);
    }
}

// Intercepted write() system call
ssize_t write(int fd, const void *buf, size_t count) {
    // Check if writing to critical file
    char proc_path[256];
    char link_path[512];
    snprintf(proc_path, sizeof(proc_path), "/proc/self/fd/%d", fd);

    ssize_t len = readlink(proc_path, link_path, sizeof(link_path) - 1);
    if (len != -1) {
        link_path[len] = '\0';

        if (is_security_critical(link_path)) {
            fprintf(stderr, "\n[Ubuntu Secure] Intercepted: write() to '%s'\n", link_path);

            // Request consensus
            consensus_response_t result = request_consensus("FileWrite", link_path, count);
            print_consensus_result("write()", link_path, &result);

            if (!result.approved) {
                fprintf(stderr, "[Ubuntu Secure] ⚠️  Write BLOCKED by consensus\n");
                errno = EPERM;
                return -1;
            }

            fprintf(stderr, "[Ubuntu Secure] ✓ Write APPROVED by consensus\n");
        }
    }

    return original_write(fd, buf, count);
}

// Intercepted execve() system call
int execve(const char *filename, char *const argv[], char *const envp[]) {
    fprintf(stderr, "\n[Ubuntu Secure] Intercepted: execve('%s')\n", filename);

    // All process execution requires consensus
    consensus_response_t result = request_consensus("ProcessExec", filename, 0);
    print_consensus_result("execve()", filename, &result);

    if (!result.approved) {
        fprintf(stderr, "[Ubuntu Secure] ⚠️  Execution BLOCKED by consensus\n");
        errno = EPERM;
        return -1;
    }

    fprintf(stderr, "[Ubuntu Secure] ✓ Execution APPROVED by consensus\n");
    return original_execve(filename, argv, envp);
}

// Intercepted chmod() system call
int chmod(const char *pathname, mode_t mode) {
    if (is_security_critical(pathname)) {
        fprintf(stderr, "\n[Ubuntu Secure] Intercepted: chmod('%s', %o)\n", pathname, mode);

        // Request consensus
        consensus_response_t result = request_consensus("PermissionChange", pathname, mode);
        print_consensus_result("chmod()", pathname, &result);

        if (!result.approved) {
            fprintf(stderr, "[Ubuntu Secure] ⚠️  Permission change BLOCKED by consensus\n");
            errno = EPERM;
            return -1;
        }

        fprintf(stderr, "[Ubuntu Secure] ✓ Permission change APPROVED by consensus\n");
    }

    return original_chmod(pathname, mode);
}

// Intercepted unlink() system call
int unlink(const char *pathname) {
    if (is_security_critical(pathname)) {
        fprintf(stderr, "\n[Ubuntu Secure] Intercepted: unlink('%s')\n", pathname);

        // Request consensus
        consensus_response_t result = request_consensus("FileDelete", pathname, 0);
        print_consensus_result("unlink()", pathname, &result);

        if (!result.approved) {
            fprintf(stderr, "[Ubuntu Secure] ⚠️  Deletion BLOCKED by consensus\n");
            errno = EPERM;
            return -1;
        }

        fprintf(stderr, "[Ubuntu Secure] ✓ Deletion APPROVED by consensus\n");
    }

    return original_unlink(pathname);
}