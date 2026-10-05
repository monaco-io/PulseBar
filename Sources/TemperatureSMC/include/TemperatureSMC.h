#ifndef PULSEBAR_TEMPERATURE_SMC_H
#define PULSEBAR_TEMPERATURE_SMC_H

#include <stdbool.h>
#include <stdint.h>

// Read-only AppleSMC access. No write command, helper, or privileged operation.
// A zero connection means that this machine or process cannot access the service.
uint32_t PBTemperatureSMCOpen(void);
void PBTemperatureSMCClose(uint32_t connection);
bool PBTemperatureSMCKeyInfo(uint32_t connection, uint32_t key,
                             uint32_t *dataType, uint32_t *dataSize);
bool PBTemperatureSMCRead(uint32_t connection, uint32_t key,
                          uint32_t dataSize, uint8_t *bytes);

#endif
