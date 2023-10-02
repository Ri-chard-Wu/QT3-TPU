

#include "tinyTPU_access.h"
#include <errno.h>
#include <math.h>



int32_t write_weight_vector(tpu_vector_t *weight_vector, uint32_t weight_address) {

	if(weight_address >= WEIGHT_BUFFER_SIZE) return EFAULT;

	weight_address <<= (uint32_t)(ceil(log2(TPU_VECTOR_SIZE)));

	for(uint32_t i = 0; i < TPU_VECTOR_SIZE; i+=sizeof(uint32_t)) {
		WRITE_32(TPU_WEIGHT_BUFFER_BASE+weight_address+i, weight_vector->transfer_vector[i/sizeof(uint32_t)]);
	}

	return 0;
}




// buffer_address: vector idx (1st vector, 2nd vector, ...).
int32_t write_input_vector(tpu_vector_t *input_vector, uint32_t buffer_address) {
	if(buffer_address >= UNIFIED_BUFFER_SIZE) return EFAULT;

	// since buffer_address is just idx, to get addree we need to multiply by byte numbers of each vector.
	buffer_address <<= (uint32_t)(ceil(log2(TPU_VECTOR_SIZE)));

	// TPU_VECTOR_SIZE: in bytes.
	for(uint32_t i = 0; i < TPU_VECTOR_SIZE; i+=sizeof(uint32_t)) {
		WRITE_32(TPU_UNIFIED_BUFFER_BASE + buffer_address + i, input_vector->transfer_vector[i / sizeof(uint32_t)]);
	}

	return 0;
}


int32_t read_output_vector(tpu_vector_t *output_vector, uint32_t buffer_address) {
	if(buffer_address >= UNIFIED_BUFFER_SIZE) return EFAULT;

	buffer_address <<= (uint32_t)(ceil(log2(TPU_VECTOR_SIZE)));

	for(uint32_t i = 0; i < TPU_VECTOR_SIZE; i+=sizeof(uint32_t)) {
		output_vector->transfer_vector[i/sizeof(uint32_t)] = READ_32(TPU_UNIFIED_BUFFER_BASE+buffer_address+i);
	}

	return 0;
}





// no address is needed, since instructions are stored in fifo.
int32_t write_instruction(instruction_t *instruction) {
	WRITE_32(TPU_INSTRUCTION_BASE + TPU_LOWER_WORD_OFFSET, instruction->lower_word);
	WRITE_32(TPU_INSTRUCTION_BASE + TPU_MIDDLE_WORD_OFFSET, instruction->middle_word);
	WRITE_16(TPU_INSTRUCTION_BASE + TPU_UPPER_WORD_OFFSET, instruction->upper_word);

	return 0;
}



int32_t read_runtime(uint32_t* runtime_cycles) {
	*runtime_cycles = READ_32(TPU_INSTRUCTION_BASE);

	return 0;
}
