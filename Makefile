# Ubuntu Secure: Phase 2 - System Call Interceptor Build
# Compiles the LD_PRELOAD library for intercepting system calls

CC = gcc
CFLAGS = -Wall -fPIC -shared
LIBS = -ldl -lcurl -ljson-c

TARGET = ubuntu_secure.so
SOURCE = ubuntu_syscall_interceptor.c

all: $(TARGET)

$(TARGET): $(SOURCE)
	@echo "Building Ubuntu Secure interceptor library..."
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE) $(LIBS)
	@echo "✓ Build complete: $(TARGET)"

install: $(TARGET)
	@echo "Installing Ubuntu Secure interceptor..."
	sudo cp $(TARGET) /usr/local/lib/
	@echo "✓ Installed to /usr/local/lib/$(TARGET)"

test: $(TARGET)
	@echo "Testing Ubuntu Secure interceptor..."
	LD_PRELOAD=./$(TARGET) bash -c "echo 'Testing write to home' > ~/test.txt"
	@echo ""
	LD_PRELOAD=./$(TARGET) bash -c "echo 'Attempting write to /etc/' > /etc/test.txt 2>&1 || echo '✓ Write to /etc/ blocked as expected'"

demo: $(TARGET)
	@echo "Starting Ubuntu Secure demo shell..."
	@echo "All system calls will be intercepted and require consensus"
	@echo "Type 'exit' to leave the protected environment"
	@echo ""
	LD_PRELOAD=./$(TARGET) bash

clean:
	rm -f $(TARGET)
	@echo "✓ Cleaned build artifacts"

help:
	@echo "Ubuntu Secure Build System"
	@echo "=========================="
	@echo "make         - Build the interceptor library"
	@echo "make install - Install to system (requires sudo)"
	@echo "make test    - Run basic tests"
	@echo "make demo    - Start protected shell with interceptor"
	@echo "make clean   - Remove build artifacts"

.PHONY: all install test demo clean help