

from pynq import MMIO
import numpy as np


TPU_BASE 				= 0x43C00000
TPU_WEIGHT_BUFFER_BASE  = 0       # relative to TPU_BASE.
TPU_UNIFIED_BUFFER_BASE = 0x80000 # relative to TPU_BASE.
TPU_INSTRUCTION_BASE    = 0x90000 # relative to TPU_BASE.
TPU_ADDRESS_RANGE = 0x100000

TPU_VECTOR_SIZE = 14
WEIGHT_BUFFER_SIZE = 32768

WORD_SIZE = 4 # in bytes.


mmio = MMIO(TPU_BASE, TPU_ADDRESS_RANGE)
# mmio.write(ADDRESS_OFFSET, data)
# result = mmio.read(ADDRESS_OFFSET)

def write_weight_vector(vec, addr):
	
    if(addr >= WEIGHT_BUFFER_SIZE): return 1

    # addr == 0, 16, 32, ... in successive calls to write_weight_vector().
    addr = addr << int(np.ceil(np.log2(TPU_VECTOR_SIZE)))




	# for(uint32_t i = 0; i < TPU_VECTOR_SIZE; i+=sizeof(uint32_t)) {
	# 	WRITE_32(TPU_WEIGHT_BUFFER_BASE + addr + i, 
    #                     weight_vector->transfer_vector[i/sizeof(uint32_t)]);
	# }

    # i == 0, 4, 8, ..., 12.
    for i in range(0, TPU_VECTOR_SIZE, WORD_SIZE):
        
        data = vec[i + 3] << 24 | vec[i + 2] << 16 | vec[i + 1] << 8 | vec[i]
        
        mmio.write(TPU_WEIGHT_BUFFER_BASE + addr + i, int(data))
	

    return 0


def write_weights(fd):
    
    print("[write_weights()]")

    weight_addr = 0

    # if(getline(&message, &messageLen, fp) == -1) {
    #     printf("Error reading line!\n\r");
    # }  

    line = fd.readline().strip()
    
    # if ((pos=strchr(message, '\n')) != NULL) *pos = '\0';
    # if ((pos=strchr(message, '\r')) != NULL) *pos = '\0';
   
    while (line != "]"):
    
        # print(line.split(','))
        
        vec = line[1:-1].split(',')
        if(len(vec) != TPU_VECTOR_SIZE): 
            print(f"Vector len != {TPU_VECTOR_SIZE}.")
        
        vec = [int(i) for i in vec]
        vec.extend([0, 0]) # padding to make its len multiple of 4 (bytes).
        
        if(write_weight_vector(vec, weight_addr)):
            print("Bad address!\n\r")
        
        # print(f"{weight_addr + 2}: {vec}") 

        weight_addr += 1


        line = fd.readline().strip()
      



# inputFiles = ["weights.txt","inputs.txt","instructions.txt", "readResultCmds.txt"]

inputFiles = ["weights.txt"]

for inputFile in inputFiles:

    fd = open(inputFile, "r")
    line = fd.readline().strip()
    
    
    
    if("weights:[" == line):
        write_weights(fd)   
    # elif("inputs:[" in line):
    # elif("instructions:[" in line):
    # elif("results:[" in line):