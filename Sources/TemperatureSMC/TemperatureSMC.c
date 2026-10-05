#include "TemperatureSMC.h"
#include <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <stddef.h>
#include <string.h>

// AppleSMC's user-client ABI is undocumented and may become unavailable.
// Keep the wire layout fixed, validate every response, and fail closed.
typedef struct {
    uint8_t major, minor, build, reserved;
    uint16_t release;
} SMCVersion;

typedef struct {
    uint16_t version, length;
    uint32_t cpu, gpu, memory;
} SMCLimits;

typedef struct {
    uint32_t dataSize, dataType;
    uint8_t attributes;
} SMCKeyInfo;

typedef struct {
    uint32_t key;
    SMCVersion version;
    SMCLimits limits;
    SMCKeyInfo keyInfo;
    uint8_t result, status, command;
    uint32_t data;
    uint8_t bytes[32];
} SMCMessage;

_Static_assert(sizeof(SMCMessage) == 80, "Unexpected AppleSMC wire layout");
_Static_assert(offsetof(SMCMessage, keyInfo) == 28, "Unexpected key-info offset");
_Static_assert(offsetof(SMCMessage, command) == 42, "Unexpected command offset");
_Static_assert(offsetof(SMCMessage, bytes) == 48, "Unexpected data offset");

static bool readMessage(uint32_t connection, const SMCMessage *input, SMCMessage *output) {
    if (!connection) return false;
    memset(output, 0, sizeof(*output));
    size_t outputSize = sizeof(*output);
    kern_return_t result = IOConnectCallStructMethod(connection, 2, input,
        sizeof(*input), output, &outputSize);
    return result == KERN_SUCCESS && outputSize == sizeof(*output) &&
           output->result == 0 && output->status == 0;
}

uint32_t PBTemperatureSMCOpen(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return 0;
    io_connect_t connection = 0;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    if (result != KERN_SUCCESS) return 0;
    return connection;
}

void PBTemperatureSMCClose(uint32_t connection) {
    if (connection) IOServiceClose(connection);
}

bool PBTemperatureSMCKeyInfo(uint32_t connection, uint32_t key,
                             uint32_t *dataType, uint32_t *dataSize) {
    if (!dataType || !dataSize) return false;
    *dataType = 0;
    *dataSize = 0;
    SMCMessage input = {0}, output = {0};
    input.key = key;
    input.command = 9; // Read key metadata.
    if (!readMessage(connection, &input, &output)) return false;
    uint32_t size = output.keyInfo.dataSize;
    if (size == 0 || size > sizeof(output.bytes)) return false;
    *dataType = output.keyInfo.dataType;
    *dataSize = size;
    return true;
}

bool PBTemperatureSMCRead(uint32_t connection, uint32_t key,
                          uint32_t dataSize, uint8_t *bytes) {
    if (!bytes || dataSize == 0 || dataSize > 32) return false;
    memset(bytes, 0, dataSize);
    SMCMessage input = {0}, output = {0};
    input.key = key;
    input.keyInfo.dataSize = dataSize;
    input.command = 5; // Read bytes. Never send command 6 (write).
    if (!readMessage(connection, &input, &output)) return false;
    memcpy(bytes, output.bytes, dataSize);
    return true;
}
