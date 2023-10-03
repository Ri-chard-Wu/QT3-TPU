

from pynq import MMIO
import numpy as np


TPU_BASE 				= 0x43C00000
TPU_WEIGHT_BUFFER_BASE  = 0       # relative to TPU_BASE.
TPU_UNIFIED_BUFFER_BASE = 0x80000 # relative to TPU_BASE.
TPU_INSTRUCTION_BASE    = 0x90000 # relative to TPU_BASE.
TPU_ADDRESS_RANGE = 0x100000

TPU_LOWER_WORD_OFFSET  = 0x4
TPU_MIDDLE_WORD_OFFSET = 0x8
TPU_UPPER_WORD_OFFSET  = 0xC

TPU_VECTOR_SIZE = 14
WEIGHT_BUFFER_SIZE = 32768
UNIFIED_BUFFER_SIZE = 4096

WORD_SIZE = 4 # in bytes.
RESULT_FILE_NAME = "results.csv"

mmio = MMIO(TPU_BASE, TPU_ADDRESS_RANGE)


def write_weights(fd):
    
    print("[write_weights()]")

    bufIdx = 0

    line = fd.readline().strip()
    
  
    while (line != "]"):
    
        # print(line.split(','))
        
        vec = line[1:-1].split(',')
        if(len(vec) != TPU_VECTOR_SIZE): 
            print(f"Vector shape not right.")
        
        vec = [int(i) for i in vec]
        vec.extend([0, 0]) # padding to make its len multiple of 4 (bytes).
        
     



        if(bufIdx >= WEIGHT_BUFFER_SIZE): 
            print("Bad address.")
            exit(1)

        # addr == 0, 16, 32, ... in successive calls to write_weight_vector().
        addr = bufIdx << int(np.ceil(np.log2(TPU_VECTOR_SIZE)))

        # i == 0, 4, 8, ..., 12.
        for i in range(0, TPU_VECTOR_SIZE, WORD_SIZE):
            data = (vec[i + 3] << 24) | (vec[i + 2] << 16) | (vec[i + 1] << 8) | vec[i]
            mmio.write(TPU_WEIGHT_BUFFER_BASE + addr + i, int(data))
        

        bufIdx += 1
        line = fd.readline().strip()
      

def write_inputs(fd):

    print("[write_inputs()]")

    bufIdx = 0 

    line = fd.readline().strip()    

    while (line != "]"):

        vec = line[1:-1].split(',')

        if(len(vec) != TPU_VECTOR_SIZE): 
            print(f"Vector shape not right.")
        
        vec = [np.uint8(i) for i in vec]
        vec.extend([np.uint8(0)] * 2 ) # padding to make its len multiple of 4 (bytes).


        if(bufIdx >= UNIFIED_BUFFER_SIZE):
            print("Bad address.")
            exit(1)

        addr = bufIdx << int(np.ceil(np.log2(TPU_VECTOR_SIZE)))

        for i in range(0, TPU_VECTOR_SIZE, WORD_SIZE):
            data = (vec[i + 3] << 24) | (vec[i + 2] << 16) | (vec[i + 1] << 8) | vec[i]
            mmio.write(TPU_UNIFIED_BUFFER_BASE + addr + i, int(data))


        print(f"{bufIdx + 2}: {vec}")


        bufIdx += 1
        line = fd.readline().strip()

    


def write_instructions(fd):

    print("[write_instructions()]")
    
    line = fd.readline().strip()
    
    while(line != "]"):
  
        vec = line[1:-1].split(',')        
        if(len(vec) > 4):
            print("Out of bounds!")
        vec = [int(i) for i in vec]
    
        b = []
        b.append(np.uint8(vec[0]))
        b.extend([np.uint8(i) for i in list(vec[1].to_bytes(4, 'little'))])

        if(len(vec) <= 3):
            b.extend([np.uint8(i) for i in list(vec[2].to_bytes(5, 'little'))])
        else:
            b.extend([np.uint8(i) for i in list(vec[2].to_bytes(2, 'little'))])
            b.extend([np.uint8(i) for i in list(vec[3].to_bytes(3, 'little'))])
        
        b.extend([np.uint8(0)] * 2) # padding
        
        for w_i in range(3):
            
            word = 0
            
            for b_i in range(3):
                word = word | (b[4 * w_i + b_i] << (8 * b_i))
            
            mmio.write(TPU_INSTRUCTION_BASE + 0x4 * (w_i + 1), int(word))

        line = fd.readline().strip()

    

def read_results(fd):

    result_file_fd = open(RESULT_FILE_NAME, "w")
    line = fd.readline().strip()    

    while(line != "]"):

        vec = line[1:-1].split(',')
        if(len(vec) > 3):
            print("Out of bounds!")

        vec = [int(i) for i in vec]
        bufIdx_base = vec[0]
        length = vec[1]

        for j in range(length):
            
            bufIdx = bufIdx_base + j
            if(bufIdx >= UNIFIED_BUFFER_SIZE):
                print("Bad address!")

            addr = bufIdx << int(np.ceil(np.log2(TPU_VECTOR_SIZE)))

            words = []
            for i in range(0, TPU_VECTOR_SIZE, WORD_SIZE):
                words.append(int(mmio.read(TPU_UNIFIED_BUFFER_BASE + addr + i)))
            
            b = []
            for word in words:
                b.extend([np.uint8(i) for i in list(word.to_bytes(4, 'little'))])

            result_file_fd.write(f"{b[0]},{b[1]},{b[2]},{b[3]},{b[4]},{b[5]},{b[6]},{b[7]},{b[8]},{b[9]},{b[10]},{b[11]},{b[12]},{b[13]}\n")
            
        line = fd.readline().strip()  
    

    result_file_fd.close()

          

# inputFiles = ["weights.txt","inputs.txt","instructions.txt", "readResultCmds.txt"]

inputFiles = ["weights.txt","inputs.txt","instructions.txt", "readResultCmds.txt"]

for inputFile in inputFiles:

    fd = open(inputFile, "r")
    line = fd.readline().strip()
    
    if("weights:[" == line):
        write_weights(fd)   
    elif("inputs:[" in line):
        write_inputs(fd)  
    elif("instructions:[" in line):
        write_instructions(fd)  
    elif("results:[" in line):
        read_results(fd)    


    fd.close()