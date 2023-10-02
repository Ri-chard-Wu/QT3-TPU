

#include "tinyTPU_access.h"
#define _GNU_SOURCE
// #include "platform.h"
// #include "xil_exception.h"
// #include "xscugic.h"
// #include "xparameters.h"
// #include "xparameters_ps.h"
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
// #include <ff.h>

#define WEIGHTS "weights:["
#define INPUTS "inputs:["
#define INSTRUCTIONS "instructions:["
#define RESULTS "results:["
#define END "]"

#define RESULT_FILE_NAME "results.csv"

#define INTC_TPU_SYNCHRONIZE_ID	XPS_FPGA0_INT_ID



// static XScuGic INTCInst;

volatile char synchronize_happened;

// int setup_interrupt(void);
// void synchronize_isr(void* vp);



int main(void) {
	// init_platform();

	synchronize_happened = 0;
	// if(setup_interrupt() != XST_SUCCESS) printf("Coulnd't configure interrupts!\n\r");

	char *message;
    size_t messageLen = 0;

	// FILE file;
	// FATFS file_system;
	// FRESULT result;
    int result;

	// result = f_mount(&file_system, "0:/", 0);

	// if(result != FR_OK) {
	// 	printf("Error mounting SD card!\n\r");
	// }

    char *inputFiles[3] = {"weights.txt","inputs.txt","instructions.txt"};

	for(int fidx = 2; fidx < 3; fidx++) {

        // printf("filename: %s\n", inputFiles[fidx]);

        FILE * fp;
        fp = fopen(inputFiles[fidx], "r");
        if (fp == NULL) {
			printf("Error opening file %s with error code %d!\n\r", message, result);
			continue;
		}

        result = fseek(fp, 0, SEEK_SET);
		if(result) {
			printf("Error jumping to start!\n\r");
			continue;
		}
		

        if(getline(&message, &messageLen, fp) == -1) {
            break; // End of file
        }      

        
        char *pos;


        // replace \n or \r by \0.
        if ((pos = strchr(message, '\n')) != NULL) *pos = '\0';
        if ((pos = strchr(message, '\r')) != NULL) *pos = '\0';

        printf("Message was: %s\n\r", message);



        // printf("message: %s\n", message);
        // printf("WEIGHTS: %s\n", WEIGHTS);
        // printf("strncmp(WEIGHTS, message, sizeof(WEIGHTS)): %d\n", strncmp(WEIGHTS, message, sizeof(WEIGHTS)));

        
        if(strncmp(WEIGHTS, message, sizeof(WEIGHTS)) == 0) {
            
        
            uint32_t weight_addr = 0;

            if(getline(&message, &messageLen, fp) == -1) {
                printf("Error reading line!\n\r");
            }  
            
            if ((pos=strchr(message, '\n')) != NULL) *pos = '\0';
            if ((pos=strchr(message, '\r')) != NULL) *pos = '\0';
            

            // message: e.g. "[1,2,3]\n".
            // int idx = 2;
            while(strncmp(END, message, sizeof(END)) != 0) {

                

                tpu_vector_t vector;

                uint32_t i = 0;

                // split by '[', ',', or ']'.
                char *str = strtok(message, "[,]");

                // printf("%d: ", idx++);
                while(str != NULL) {

                    if(i >= TPU_VECTOR_SIZE) {
                        printf("Vector out of bounds!\n\r");
                    }

                    vector.byte_vector[i++] = atoi(str);
                    // printf("%d,", atoi(str));

                    str = strtok(NULL, "[,]");
                }
                // printf("\n");

                if(i < TPU_VECTOR_SIZE) {
                    printf("Vector to small!\n\r");
                }

                // if(write_weight_vector(&vector, weight_addr++)) {
                // 	printf("Bad address!\n\r");
                // } 

                if(getline(&message, &messageLen, fp) == -1) {
                    printf("Error reading line!\n\r");
                }                      

                if ((pos=strchr(message, '\n')) != NULL) *pos = '\0';
                if ((pos=strchr(message, '\r')) != NULL) *pos = '\0';
            }


        }
        else if(strncmp(INPUTS, message, sizeof(INPUTS)) == 0) {

            uint32_t input_addr = 0;

            // if(f_gets(message, sizeof(message), &file) != message) {
            // 	printf("Error reading line!\n\r");
            // }
            if(getline(&message, &messageLen, fp) == -1) {
                printf("Error reading line!\n\r");
            }                   

            if ((pos=strchr(message, '\n')) != NULL) *pos = '\0';
            if ((pos=strchr(message, '\r')) != NULL) *pos = '\0';

            // int idx = 2;
            while(strncmp(END, message, sizeof(END)) != 0) {
                tpu_vector_t vector;

                uint32_t i = 0;
                char *str = strtok(message, "[,]");

                // printf("%d: ", idx++);
                while(str != NULL) {
                    if(i >= TPU_VECTOR_SIZE) {
                        printf("Vector out of bounds!\n\r");
                    }
                    vector.byte_vector[i++] = atoi(str);
                    // printf("%d,", atoi(str));
                    
                    str = strtok(NULL, "[,]");
                }
                // printf("\n");

                if(i < TPU_VECTOR_SIZE-1) {
                    printf("Vector to small!\n\r");
                }

                // if(write_input_vector(&vector, input_addr++)) {
                // 	printf("Bad address!\n\r");
                // }

                if(getline(&message, &messageLen, fp) == -1) {
                    printf("Error reading line!\n\r");
                }     

                if ((pos=strchr(message, '\n')) != NULL) *pos = '\0';
                if ((pos=strchr(message, '\r')) != NULL) *pos = '\0';
            }
        }
        else if(strncmp(INSTRUCTIONS, message, sizeof(INSTRUCTIONS)) == 0) {
            
            instruction_t instructions[512];
            char done = 0;
            
            int idx = 2;
            while(!done) {

                int32_t i = 0;
                // printf("sizeof(instructions): %d\n", sizeof(instructions) / sizeof(instruction_t));
                for(; i < sizeof(instructions) / sizeof(instruction_t); ++i) {
                
     

                    if(getline(&message, &messageLen, fp) == -1) {
                        printf("Error reading line!\n\r");
                        exit(1);
                    }     
      
                    // replace \n or \r by \0.
                    if ((pos=strchr(message, '\n')) != NULL) *pos = '\0';
                    if ((pos=strchr(message, '\r')) != NULL) *pos = '\0';

                    if(strncmp(END, message, sizeof(END)) == 0) {
                        done = 1;
                        break;
                    }

                    uint32_t j = 0;

                    uint8_t op_code;
                    uint32_t calc_length;
                    uint16_t acc_addr;
                    uint32_t buffer_addr;
                    uint64_t weight_addr;

                    

                    char *str = strtok(message, "[,]");
                    printf("%d, %d: ", i, idx++);
                    while(str != NULL) {
                        
                        if(j >= 4) {
                            printf("Out of bounds!\n\r");
                        }

                        // strtoul: Convert string to unsigned long integer
                        printf("%ld,", strtoul(str, NULL, 0));
                        switch(j) {
                            case 0:
                                
                                op_code = strtoul(str, NULL, 0);
                                break;
                            case 1:
                                calc_length = strtoul(str, NULL, 0);
                                break;
                            case 2:
                                acc_addr = strtoul(str, NULL, 0);
                                weight_addr = strtoul(str, NULL, 0);
                                break;
                            case 3:
                                buffer_addr = strtoul(str, NULL, 0);
                                break;
                        }

                        j++;
                        str = strtok(NULL, "[,]");
                    }

                    printf("\n");


                    instructions[i].op_code = op_code;
                    instructions[i].calc_length[0] = calc_length;
                    instructions[i].calc_length[1] = calc_length >> 8;
                    instructions[i].calc_length[2] = calc_length >> 16;
                    instructions[i].calc_length[3] = calc_length >> 24;

                    if(j <= 3) {
                        instructions[i].weight_address[0] = weight_addr;
                        instructions[i].weight_address[1] = weight_addr >> 8;
                        instructions[i].weight_address[2] = weight_addr >> 16;
                        instructions[i].weight_address[3] = weight_addr >> 24;
                        instructions[i].weight_address[4] = weight_addr >> 32;
                    } 
                    else {
                        instructions[i].acc_address[0] = acc_addr;
                        instructions[i].acc_address[1] = acc_addr >> 8;
                        instructions[i].buf_address[0] = buffer_addr;
                        instructions[i].buf_address[1] = buffer_addr >> 8;
                        instructions[i].buf_address[2] = buffer_addr >> 16;
                    }

                    // printf("Added instruction 0x%04x%08x%08x\n\r", instructions[i].upper_word, instructions[i].middle_word, instructions[i].lower_word);

                    
                }

                // for(uint32_t x = 0; x < i; ++x) {
                //     write_instruction(&instructions[x]);
                // }
            }



            // while(!synchronize_happened);
            // synchronize_happened = 0;
            // printf("Calculations finished.\n\r");
            // uint32_t cycles;
            
            // if(read_runtime(&cycles)) {
            // 	printf("Bad address!\n\r");
            // } 
            // else {
            // 	printf("Calculations took %d cycles/%f nanoseconds to complete.\n\r", cycles, cycles*TPU_CLOCK_CYCLE);
            // }

        }
        // else if(strncmp(RESULTS, message, sizeof(RESULTS)) == 0) {

        // 	if(f_gets(message, sizeof(message), &file) != message) {
        // 		printf("Error reading line!\n\r");
        // 	}

        // 	if ((pos=strchr(message, '\n')) != NULL) *pos = '\0';
        // 	if ((pos=strchr(message, '\r')) != NULL) *pos = '\0';

        // 	FIL result_file;

        // 	FILINFO info;
        // 	if(f_stat(RESULT_FILE_NAME, &info) == FR_OK) {
        // 		result = f_open(&result_file, RESULT_FILE_NAME, FA_WRITE);
        // 	} 
        // 	else {
        // 		result = f_open(&result_file, RESULT_FILE_NAME, FA_WRITE | FA_CREATE_ALWAYS);
        // 	}


        // 	if(result) {
        // 		printf("Error creating file!\n\r");
        // 	}


        // 	if(f_lseek(&result_file, result_file.fsize)) {
        // 		printf("Error jumping to end of file!\n\r");
        // 	}


        // 	while(strncmp(END, message, sizeof(END)) != 0) {

        // 		uint32_t i = 0;

        // 		uint32_t address;
        // 		uint32_t length;
        // 		char append;

        // 		char *str = strtok(message, "[,]");

        // 		while(str != NULL) {

        // 			if(i >= 3) {
        // 				printf("Out of bounds!\n\r");
        // 			}

        // 			switch(i) {
        // 				case 0:
        // 					address = strtoul(str, NULL, 0);
        // 					break;
        // 				case 1:
        // 					length = strtoul(str, NULL, 0);
        // 					break;
        // 				case 2:
        // 					append = strtoul(str, NULL, 0);
        // 			}

        // 			i++;
        // 			str = strtok(NULL, "[,]");
        // 		}


        // 		if(!append) {
        // 			if(f_lseek(&result_file, 0)) {
        // 				printf("Error jumping to start of file!\n\r");
        // 			}
        // 		}


        // 		tpu_vector_t vector;
        // 		for(uint32_t j = 0; j < length; j++) {

        // 			// if(read_output_vector(&vector, address+j)) {
        // 			// 	printf("Bad address!\n\r");
        // 			// } 
        // 			// else {
        // 			// 	f_printf(&result_file, "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n"
        // 			// 		, vector.byte_vector[0]
        // 			// 		, vector.byte_vector[1]
        // 			// 		, vector.byte_vector[2]
        // 			// 		, vector.byte_vector[3]
        // 			// 		, vector.byte_vector[4]
        // 			// 		, vector.byte_vector[5]
        // 			// 		, vector.byte_vector[6]
        // 			// 		, vector.byte_vector[7]
        // 			// 		, vector.byte_vector[8]
        // 			// 		, vector.byte_vector[9]
        // 			// 		, vector.byte_vector[10]
        // 			// 		, vector.byte_vector[11]
        // 			// 		, vector.byte_vector[12]
        // 			// 		, vector.byte_vector[13]
        // 			// 	);
        // 			// }
        // 		}


        // 		if(f_gets(message, sizeof(message), &file) != message) {
        // 			printf("Error reading line!\n\r");
        // 		}

        // 		if ((pos=strchr(message, '\n')) != NULL) *pos = '\0';
        // 		if ((pos=strchr(message, '\r')) != NULL) *pos = '\0';
        // 	}
        // 	if(f_truncate(&result_file)) {
        // 		printf("Error truncating file!\n\r");
        // 	}
        // 	if(f_close(&result_file)) {
        // 		printf("Error closing file!\n\r");
        // 	}
        // }

   
    

        fclose(fp);

	}

	return 0;
}


