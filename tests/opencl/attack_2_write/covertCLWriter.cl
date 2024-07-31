// Should be in common.h but it doesn't like to compile for AMD
// devices. Probably need to figure out some command line arg or a
// preprocessor scripe

// common.h start

#define MAX_SHMEM_SIZE 65536

#if !defined(SHARED_MEMORY_SIZE) 
#define SHARED_MEMORY_SIZE_INT (MAX_SHMEM_SIZE/4)
#endif

// In case we want to try out of bounds accesses
#if !defined(SHARED_MEMORY_SIZE_TRAVERSED) 
#define SHARED_MEMORY_SIZE_TRAVERSED (SHARED_MEMORY_SIZE_INT)
#endif

// common.h end


__kernel void covertWriter(__global volatile int *A, __global volatile int *B, __global volatile int *C) {
  local volatile int lm[SHARED_MEMORY_SIZE_INT];
  uint id = get_global_id(0);
  
  for (uint i = get_local_id(0); i < SHARED_MEMORY_SIZE_TRAVERSED; i+=get_local_size(0)) {
    lm[i] = B[id];
  }
  
  // So that the compiler doesn't optimize away the local memory
  for (uint i = get_local_id(0); i < SHARED_MEMORY_SIZE_TRAVERSED; i+=get_local_size(0)) {
    A[id] = lm[id];
    B[id] = lm[id];
    C[id] = lm[id];
  }
  
}