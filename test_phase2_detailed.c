#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

int main() {
    printf("Phase 2 Detailed Test: Direct System Calls\n");
    printf("==========================================\n\n");

    // Test 1: Try to open /etc/passwd for writing
    printf("Test 1: Attempting to open /etc/passwd for writing...\n");
    int fd = open("/etc/passwd", O_WRONLY | O_APPEND);
    if (fd < 0) {
        printf("Result: BLOCKED ✓ (errno=%d: %s)\n", errno, strerror(errno));
    } else {
        printf("Result: ALLOWED ✗ (This should have been blocked!)\n");
        close(fd);
    }
    printf("\n");

    // Test 2: Try to open /tmp/test.txt for writing
    printf("Test 2: Attempting to open /tmp/test.txt for writing...\n");
    fd = open("/tmp/test.txt", O_WRONLY | O_CREAT, 0644);
    if (fd < 0) {
        printf("Result: BLOCKED ✗ (errno=%d: %s)\n", errno, strerror(errno));
    } else {
        printf("Result: ALLOWED ✓ (User file operations should work)\n");
        write(fd, "test\n", 5);
        close(fd);
        unlink("/tmp/test.txt");
    }
    printf("\n");

    // Test 3: Try to chmod /etc/shadow
    printf("Test 3: Attempting to chmod /etc/shadow...\n");
    int result = chmod("/etc/shadow", 0777);
    if (result < 0) {
        printf("Result: BLOCKED ✓ (errno=%d: %s)\n", errno, strerror(errno));
    } else {
        printf("Result: ALLOWED ✗ (This should have been blocked!)\n");
    }
    printf("\n");

    // Test 4: Try to unlink (delete) /etc/hosts
    printf("Test 4: Attempting to delete /etc/hosts...\n");
    result = unlink("/etc/hosts");
    if (result < 0) {
        printf("Result: BLOCKED ✓ (errno=%d: %s)\n", errno, strerror(errno));
    } else {
        printf("Result: ALLOWED ✗ (This should have been blocked!)\n");
    }
    printf("\n");

    printf("==========================================\n");
    printf("Test complete. Critical operations should be blocked.\n");

    return 0;
}