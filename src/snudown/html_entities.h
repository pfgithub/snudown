#ifndef HTML_ENTITIES_H
#define HTML_ENTITIES_H

#include <stdint.h>
#include <stdlib.h>

extern const uint32_t MAX_NUM_ENTITY_VAL;

extern const size_t MAX_NUM_ENTITY_LEN;

int is_valid_numeric_entity(uint32_t entity_val);

const char *is_allowed_named_entity(const char *str, size_t len);

#endif