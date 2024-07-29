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
#include <unordered_map>

// Define constants if not provided
#ifndef MAX_SHMEM_SIZE
#define MAX_SHMEM_SIZE 65536 // Define a suitable size if not already defined
#endif

#ifndef SHARED_MEMORY_SIZE_TRAVERSED
#define SHARED_MEMORY_SIZE_TRAVERSED (MAX_SHMEM_SIZE / 4)
#endif

#define KERNEL_NAME "covertListener"

#define CL_CHECK(_expr)                                                \
   do {                                                                \
     cl_int _err = _expr;                                              \
     if (_err == CL_SUCCESS)                                           \
       break;                                                          \
     std::cerr << "OpenCL Error: " << #_expr << " returned " << _err << "!\n";   \
     cleanup();                                                        \
     exit(-1);                                                         \
   } while (0)

#define CL_CHECK2(_expr)                                               \
   ({                                                                  \
     cl_int _err = CL_INVALID_VALUE;                                   \
     decltype(_expr) _ret = _expr;                                     \
     if (_err != CL_SUCCESS) {                                         \
       std::cerr << "OpenCL Error: " << #_expr << " returned " << _err << "!\n"; \
       cleanup();                                                      \
       exit(-1);                                                       \
     }                                                                 \
     _ret;                                                             \
   })

cl_device_id device_id = nullptr;
cl_context context = nullptr;
cl_command_queue commandQueue = nullptr;
cl_program program = nullptr;
cl_kernel kernel = nullptr;
cl_mem buffer_A = nullptr;
cl_mem buffer_B = nullptr;
cl_mem buffer_C = nullptr;

static void cleanup() {
    if (commandQueue) clReleaseCommandQueue(commandQueue);
    if (kernel) clReleaseKernel(kernel);
    if (program) clReleaseProgram(program);
    if (buffer_A) clReleaseMemObject(buffer_A);
    if (buffer_B) clReleaseMemObject(buffer_B);
    if (buffer_C) clReleaseMemObject(buffer_C);
    if (context) clReleaseContext(context);
    if (device_id) clReleaseDevice(device_id);
}

// Function to read the kernel source code
static int read_kernel_file(const char* filename, char** data, size_t* size) {
    std::ifstream file(filename, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        std::cerr << "Failed to load kernel.\n";
        return -1;
    }
    std::streamsize fsize = file.tellg();
    file.seekg(0, std::ios::beg);
    *data = (char*)malloc(fsize + 1);
    if (file.read(*data, fsize)) {
        (*data)[fsize] = '\0';
        *size = fsize;
    } else {
        free(*data);
        std::cerr << "Failed to read kernel file.\n";
        return -1;
    }
    return 0;
}

int main(int argc, char* argv[]) {
    cl_platform_id platform_id;
    size_t kernel_size;

    // Getting platform and device information
    CL_CHECK(clGetPlatformIDs(1, &platform_id, NULL));
    CL_CHECK(clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_DEFAULT, 1, &device_id, NULL));

    std::cout << "Create context\n";
    context = CL_CHECK2(clCreateContext(NULL, 1, &device_id, NULL, NULL, &_err));

    std::cout << "Allocate device buffers\n";
    size_t size = MAX_SHMEM_SIZE;
    buffer_A = CL_CHECK2(clCreateBuffer(context, CL_MEM_READ_WRITE, size, NULL, &_err));
    buffer_B = CL_CHECK2(clCreateBuffer(context, CL_MEM_READ_WRITE, size, NULL, &_err));
    buffer_C = CL_CHECK2(clCreateBuffer(context, CL_MEM_READ_WRITE, size, NULL, &_err));

    std::cout << "Read program from kernel source\n";
    char* kernel_source;
    if (0 != read_kernel_file("covertCLListener.cl", &kernel_source, &kernel_size))
        return -1;
    program = CL_CHECK2(clCreateProgramWithSource(context, 1, (const char**)&kernel_source, &kernel_size, &_err));
    free(kernel_source);

    // Build program
    CL_CHECK(clBuildProgram(program, 1, &device_id, NULL, NULL, NULL));

    // Create kernel
    kernel = CL_CHECK2(clCreateKernel(program, KERNEL_NAME, &_err));

    std::cout << "Allocate device buffers\n";
    size_t nbytes = 8 * sizeof(cl_uchar);
    buffer_A = CL_CHECK2(clCreateBuffer(context, CL_MEM_READ_ONLY, nbytes, NULL, &_err));
    buffer_B = CL_CHECK2(clCreateBuffer(context, CL_MEM_WRITE_ONLY, nbytes, NULL, &_err));
    buffer_C = CL_CHECK2(clCreateBuffer(context, CL_MEM_READ_ONLY, nbytes, NULL, &_err));

    int* A = (int*)malloc(size);
    int* B = (int*)malloc(size);
    int* C = (int*)malloc(size);
    std::cout << "Create context\n";
    // Set kernel arguments
    CL_CHECK(clSetKernelArg(kernel, 0, sizeof(cl_mem), &A));
    CL_CHECK(clSetKernelArg(kernel, 1, sizeof(cl_mem), &B));
    CL_CHECK(clSetKernelArg(kernel, 2, sizeof(cl_mem), &C));
    context = CL_CHECK2(clCreateContext(NULL, 1, &device_id, NULL, NULL, &_err));
    commandQueue = CL_CHECK2(clCreateCommandQueue(context, device_id, 0, &_err));
    std::cout << "Execute the kernel\n";
    int gridSize = 1; // replace with desired grid size
    int workgroupSize = 1; // replace with desired workgroup size
    int globalSize = gridSize * workgroupSize;


    CL_CHECK(clSetKernelArg(kernel, 0, sizeof(cl_mem), &buffer_A));
    CL_CHECK(clSetKernelArg(kernel, 1, sizeof(cl_mem), &buffer_B));
    CL_CHECK(clSetKernelArg(kernel, 2, sizeof(cl_mem), &buffer_C));

    CL_CHECK(clEnqueueNDRangeKernel(commandQueue, kernel, 1, NULL, (const size_t*)&globalSize, NULL, 0, NULL, NULL));
    CL_CHECK(clFinish(commandQueue));

    CL_CHECK(clEnqueueReadBuffer(commandQueue, buffer_C, CL_TRUE, 0, size, C, 0, NULL, NULL));

    // Process the data from C and perform the necessary actions
    std::unordered_map<int, int> observations;

    for (int i = 0; i < SHARED_MEMORY_SIZE_TRAVERSED * gridSize; i++) {
        unsigned v = C[i];
        if (observations.find(v) == observations.end()) {
            observations[v] = 1;
        } else {
            observations[v]++;
        }
    }

    std::vector<std::pair<int, int>> keyValues;
    for (const auto& i : observations) {
        keyValues.push_back(i);
    }

        CL_CHECK(clEnqueueWriteBuffer(commandQueue, buffer_A, CL_TRUE, 0, size, A, 0, NULL, NULL));
    CL_CHECK(clEnqueueWriteBuffer(commandQueue, buffer_B, CL_TRUE, 0, size, B, 0, NULL, NULL));
    CL_CHECK(clEnqueueWriteBuffer(commandQueue, buffer_C, CL_TRUE, 0, size, C, 0, NULL, NULL));

    std::sort(keyValues.begin(), keyValues.end(), [](const std::pair<int, int>& a, const std::pair<int, int>& b) {
        return a.second > b.second;
    });

    std::cout << "Top 10 observations:\n";
    int obs = 0;
    for (const auto& i : keyValues) {
        if (obs < 10) {
            std::cout << "(" << i.first << "," << i.second << ")" << std::endl;
            obs++;
        } else {
            break;
        }
    }

    free(A);
    free(B);
    free(C);

    cleanup();

    return 0;
}
