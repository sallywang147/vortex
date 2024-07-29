#include <CL/opencl.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <chrono>
#include <cassert>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <algorithm> 
#include "common.h"

#define KERNEL_NAME "DES_encrypt"

#define CL_CHECK(_expr)                                                \
   do {                                                                \
     cl_int _err = _expr;                                              \
     if (_err == CL_SUCCESS)                                           \
       break;                                                          \
     std::cerr << "OpenCL Error: " << #_expr << " returned " << _err << "!\n";   \
     cleanup();			                                                     \
     exit(-1);                                                         \
   } while (0)

#define CL_CHECK2(_expr)                                               \
   ({                                                                  \
     cl_int _err = CL_INVALID_VALUE;                                   \
     decltype(_expr) _ret = _expr;                                     \
     if (_err != CL_SUCCESS) {                                         \
       std::cerr << "OpenCL Error: " << #_expr << " returned " << _err << "!\n"; \
       cleanup();			                                                   \
       exit(-1);                                                       \
     }                                                                 \
     _ret;                                                             \
   })

cl_device_id device_id = nullptr;
cl_context context = nullptr;
cl_command_queue commandQueue = nullptr;
cl_program program = nullptr;
cl_kernel kernel = nullptr;
cl_mem input_memobj = nullptr;
cl_mem output_memobj = nullptr;
cl_mem key_memobj = nullptr;
uint8_t *kernel_source = nullptr;

static void cleanup() {
  if (commandQueue) clReleaseCommandQueue(commandQueue);
  if (kernel) clReleaseKernel(kernel);
  if (program) clReleaseProgram(program);
  if (input_memobj) clReleaseMemObject(input_memobj);
  if (output_memobj) clReleaseMemObject(output_memobj);
  if (key_memobj) clReleaseMemObject(key_memobj);
  if (context) clReleaseContext(context);
  if (device_id) clReleaseDevice(device_id);
  if (kernel_source) free(kernel_source);
}

//uint32_t size = 64;

// Read the kernel source code
static int read_kernel_file(const char* filename, unsigned char** data, size_t* size) {
  FILE* fp = fopen(filename, "rb");
  if (!fp) {
    std::cerr << "Failed to load kernel.\n";
    return -1;
  }
  fseek(fp, 0, SEEK_END);
  long fsize = ftell(fp);
  rewind(fp);

  *data = (unsigned char*)malloc(fsize + 1);
  *size = fread(*data, 1, fsize, fp);
  (*data)[fsize] = '\0'; // Null-terminate the string

  fclose(fp);
  return 0;
}

// Function to simulate cache access and measure timing differences
double measureEncryptionTime(cl_command_queue queue, cl_mem inputBuffer, cl_mem keyBuffer, size_t dataSize) {
    auto start = std::chrono::high_resolution_clock::now();

    // Execute the kernel to perform DES encryption
    CL_CHECK(clEnqueueNDRangeKernel(queue, kernel, 1, nullptr, &dataSize, nullptr, 0, nullptr, nullptr));
    CL_CHECK(clFinish(queue));

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> duration = end - start;
    return duration.count();
}

// Function to simulate cache access and measure timing differences
double measureCacheAccessTime(cl_command_queue queue, cl_mem buffer, size_t dataSize, bool cacheHit) {
    auto start = std::chrono::high_resolution_clock::now();

    if (cacheHit) {
        // Access the memory in a way that ensures cache hits
        clEnqueueReadBuffer(queue, buffer, CL_TRUE, 0, dataSize, nullptr, 0, NULL, NULL);
    } else {
        // Access the memory in a way that may cause cache misses
        for (size_t i = 0; i < dataSize; i += 256) { // Assuming 64-byte cache lines
            clEnqueueReadBuffer(queue, buffer, CL_TRUE, i, 1, nullptr, 0, NULL, NULL);
        }
    }

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> duration = end - start;
    return duration.count();
}

using namespace std;

int main(int argc, char** argv) {
  cl_platform_id platform_id;
  size_t kernel_size;



  // Getting platform and device information
  CL_CHECK(clGetPlatformIDs(1, &platform_id, NULL));
  CL_CHECK(clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_DEFAULT, 1, &device_id, NULL));

  std::cout << "Create context\n";
  context = CL_CHECK2(clCreateContext(NULL, 1, &device_id, NULL, NULL, &_err));

  std::cout << "Allocate device buffers\n";
  size_t nbytes = 8 * sizeof(cl_uchar);
  input_memobj = CL_CHECK2(clCreateBuffer(context, CL_MEM_READ_ONLY, nbytes, NULL, &_err));
  output_memobj = CL_CHECK2(clCreateBuffer(context, CL_MEM_WRITE_ONLY, nbytes, NULL, &_err));
  key_memobj = CL_CHECK2(clCreateBuffer(context, CL_MEM_READ_ONLY, nbytes, NULL, &_err));

  std::cout << "Read program from kernel source\n";
  if (0 != read_kernel_file("kernel.cl", &kernel_source, &kernel_size))
    return -1;
  program = CL_CHECK2(clCreateProgramWithSource(
    context, 1, (const char**)&kernel_source, &kernel_size, &_err));

  // Build program
  CL_CHECK(clBuildProgram(program, 1, &device_id, NULL, NULL, NULL));

  // Build program
  //CL_CHECK(clBuildProgram(program, 1, &device_id, NULL, NULL, NULL));

  // Create kernel
  kernel = CL_CHECK2(clCreateKernel(program, KERNEL_NAME, &_err));

  // Example input data (8 bytes of plaintext)
  std::vector<cl_uchar> input = {0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef};
  std::vector<cl_uchar> output(8);
  std::vector<cl_uchar> key = {0x13, 0x34, 0x57, 0x79, 0x9b, 0xbc, 0xdf, 0xf1}; // Example 8-byte key


  // Set kernel arguments
  CL_CHECK(clSetKernelArg(kernel, 0, sizeof(cl_mem), &input_memobj));
  CL_CHECK(clSetKernelArg(kernel, 1, sizeof(cl_mem), &output_memobj));
  CL_CHECK(clSetKernelArg(kernel, 2, sizeof(cl_mem), &key_memobj));

  // Creating command queue
  commandQueue = CL_CHECK2(clCreateCommandQueue(context, device_id, 0, &_err));

  std::cout << "\nUpload source buffers\n";
  CL_CHECK(clEnqueueWriteBuffer(commandQueue, input_memobj, CL_TRUE, 0, nbytes, input.data(), 0, NULL, NULL));
  CL_CHECK(clEnqueueWriteBuffer(commandQueue, key_memobj, CL_TRUE, 0, nbytes, key.data(), 0, NULL, NULL));

  std::cout << "Execute the kernel\n";
  uint32_t size = 1;
  size_t global_work_size[1] = {9 * size};
  auto time_start = std::chrono::high_resolution_clock::now();
  CL_CHECK(clEnqueueNDRangeKernel(commandQueue, kernel, 1, NULL, global_work_size, NULL, 0, NULL, NULL));
  CL_CHECK(clFinish(commandQueue));
  auto time_end = std::chrono::high_resolution_clock::now();
  double elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(time_end - time_start).count();
  std::cout << "Elapsed time: " << elapsed << " ms\n";

  std::cout << "Download destination buffer\n";
  CL_CHECK(clEnqueueReadBuffer(commandQueue, output_memobj, CL_TRUE, 0, 8, output.data(), 0, NULL, NULL));


 // Display the input
  std::cout << "\nPlaintext: \n";
  for (const auto &byte : input) {
      std::cout << std::hex << static_cast<int>(byte) << " ";
  }

    std::cout << "\nKeys used for encryption: \n";
  for (const auto &byte : key) {
      std::cout << std::hex << static_cast<int>(byte) << " ";
  }
  // Display the output (ciphertext)
  std::cout << "\nCiphertext: ";
  for (const auto &byte : output) {
      std::cout << std::hex << static_cast<int>(byte) << " ";
  }
  std::cout << std::endl;


  
  // Key guessing logic
  std::vector<cl_uchar> guessedKey = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}; // Start with some guess, iterate through possible keys
  //double bestTiming = timing;

  // Iterate through possible key values to find the one with the least timing
  double counter0 = 0;
  double total_correct = 0;
  double total_wrong = 0;
  double counter1 = 0; 
  
  ofstream csvFile;
  csvFile.open("/home/sallywang/vortex/build/output.csv"); // Create file
  for (cl_uchar guess = 0; guess <= std::numeric_limits<cl_uchar>::max(); ++guess) {
      for (int i=0; i<=8; i++){
         guessedKey[i] = guess; // Change one byte of the key for simplicity
        CL_CHECK(clEnqueueWriteBuffer(commandQueue, key_memobj, CL_TRUE, 0, nbytes, guessedKey.data(), 0, NULL, NULL));
        double newTiming = measureEncryptionTime(commandQueue, input_memobj, key_memobj, size);
      //std::cout << "Guess is: " << std::hex << static_cast<int>(guess) << "\n";
      if (guess == input[i]) {
        //std::cout << "Correct guess found: " << std::hex << static_cast<int>(guess) << " in time: " << newTiming << "ms\n";
        double cacheHitTime = measureCacheAccessTime(commandQueue, output_memobj, size, true);
        double cacheMissTime = measureCacheAccessTime(commandQueue, output_memobj, size, false);
        double correct_diff = cacheHitTime - cacheMissTime;
        csvFile << guess << "," << newTiming << "," << correct_diff << "," << "True" <<"\n";
        if (correct_diff < 0){
          counter0 += 1;
        }
        total_correct += 1; 
      } else{ 
        //std::cout << "Wrong guess: " << std::hex << static_cast<int>(guess) << " took time: " << newTiming << "ms\n";
        double cacheHitTime = measureCacheAccessTime(commandQueue, output_memobj, size, true);
        double cacheMissTime = measureCacheAccessTime(commandQueue, output_memobj, size, false);
        double wrong_diff  = cacheHitTime - cacheMissTime;
        csvFile << guess << "," << newTiming << "," << wrong_diff << "," << "False" <<"\n";
        if (wrong_diff < 0){
          counter1 += 1;
        }
        total_wrong += 1; 
      }

      }
     
  // Clean up
  }
  csvFile.close();
  std::cout << "CSV file 'output.csv' written successfully." << std::endl;
  std::cout << "(hit - cache) < 0 when guess is correct:" << counter0 << "\n";
  std::cout << " Wrong guesses where (hit - cache) < 0:" << counter1 << "\n";
  cleanup();

  return 0;
}
