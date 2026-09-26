#include "key_test.hpp"
#include <nvrtc.h>
#include <iostream>
#include <cstring>
#include <algorithm>

#define NVRTC_CALL(func, args...) error_wrapper<nvrtcResult>(#func, (func)(args), NVRTC_SUCCESS, nvrtcGetErrorString)

const char *cuGetErrorName_wrapper(CUresult err) {
    const char *msg;
    cuGetErrorName(err, &msg);
    return msg;
}

static const char sha1_cuda_src[] = R"(
typedef unsigned int u32;

#ifndef LROT32
#define LROT32(x, n) (((x)<<(n))|((x)>>(32-(n))))
#endif

extern "C" __constant__ u32 chunk_buffer[208];

__forceinline__ __device__ static
void sha1_main_loop(u32 w[16], u32 &a, u32 &b, u32 &c, u32 &d, u32 &e) {
#pragma unroll
    for (int i=0; i<80; i++) {
        u32 f, k;

        if (i < 20) {
            f = d ^ (b & (c ^ d));
            k = 0x5A827999;
        } else if (i < 40) {
            f = b ^ c ^ d;
            k = 0x6ED9EBA1;
        } else if (i < 60) {
            f = (b & c) | (b & d) | (c & d);
            k = 0x8F1BBCDC;
        } else {
            f = b ^ c ^ d;
            k = 0xCA62C1D6;
        }

        u32 wi;
        if (i < 16)
            wi = w[i];
        else
            wi = w[i%16] = LROT32(w[(i-3)%16] ^ w[(i-8)%16] ^ w[(i-14)%16] ^ w[i%16], 1);

        u32 temp = LROT32(a, 5) + f + e + k + wi;
        e = d;
        d = c;
        c = LROT32(b, 30);
        b = a;
        a = temp;
    }
}

extern "C" __global__
void proc_chunk0(u32 t0, u32* __restrict__ h0, u32* __restrict__ h1, u32* __restrict__ h2, u32* __restrict__ h3, u32* __restrict__ h4) {
    constexpr u32 a0 = 0x67452301;
    constexpr u32 b0 = 0xEFCDAB89;
    constexpr u32 c0 = 0x98BADCFE;
    constexpr u32 d0 = 0x10325476;
    constexpr u32 e0 = 0xC3D2E1F0;

    size_t index = blockIdx.x * blockDim.x + threadIdx.x;
    u32 a, b, c, d, e;

    u32 w[16];
    for (int i = 0; i < 16; i++) w[i] = chunk_buffer[i];
    w[1] = t0 - index;

    a = a0;
    b = b0;
    c = c0;
    d = d0;
    e = e0;

    sha1_main_loop(w, a, b, c, d, e);

    h0[index] = a + a0;
    h1[index] = b + b0;
    h2[index] = c + c0;
    h3[index] = d + d0;
    h4[index] = e + e0;
}

extern "C" __global__
void proc_chunk(size_t chunk_idx, u32 *h0, u32 *h1, u32 *h2, u32 *h3, u32 *h4) {
    size_t index = blockIdx.x * blockDim.x + threadIdx.x;
    u32 a, b, c, d, e;

    u32 w[16];
    for (int i = 0; i < 16; i++) w[i] = chunk_buffer[chunk_idx * 16 + i];

    a = h0[index];
    b = h1[index];
    c = h2[index];
    d = h3[index];
    e = h4[index];

    sha1_main_loop(w, a, b, c, d, e);

    h0[index] += a;
    h1[index] += b;
    h2[index] += c;
    h3[index] += d;
    h4[index] += e;
}
)";

void CudaManager::init_sha1_kernel() {
    int dev_major, dev_minor;
    CU_CALL(cuDeviceGetAttribute, &dev_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, cu_device);
    CU_CALL(cuDeviceGetAttribute, &dev_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, cu_device);
    std::string arch = "-arch=compute_" + std::to_string(dev_major) + std::to_string(dev_minor);

    nvrtcProgram prog;
    NVRTC_CALL(nvrtcCreateProgram, &prog, sha1_cuda_src, "sha1.cu", 0, NULL, NULL);
    const char *opts[] = { arch.c_str() };
    try {
        NVRTC_CALL(nvrtcCompileProgram, prog, 1, opts);
    } catch (const std::runtime_error &e) {
        size_t log_size;
        NVRTC_CALL(nvrtcGetProgramLogSize, prog, &log_size);
        std::vector<char> log(log_size);
        NVRTC_CALL(nvrtcGetProgramLog, prog, log.data());
        fprintf(stderr, "nvrtcCompileProgram for sha1 failed:\n%s\n", log.data());
        throw;
    }

    size_t ptx_size;
    NVRTC_CALL(nvrtcGetPTXSize, prog, &ptx_size);
    std::vector<char> ptx(ptx_size);
    NVRTC_CALL(nvrtcGetPTX, prog, ptx.data());
    NVRTC_CALL(nvrtcDestroyProgram, &prog);

    CU_CALL(cuModuleLoadData, &cu_module_sha1, ptx.data());
    CU_CALL(cuModuleGetFunction, &cu_proc_chunk0, cu_module_sha1, "proc_chunk0");
    CU_CALL(cuModuleGetFunction, &cu_proc_chunk, cu_module_sha1, "proc_chunk");

    size_t d_bytes;
    CU_CALL(cuModuleGetGlobal, &d_chunk_buffer, &d_bytes, cu_module_sha1, "chunk_buffer");
}

CudaManager::CudaManager(int n_block, int thread_per_block, unsigned long base_time):
        n_block_(n_block), thread_per_block_(thread_per_block), base_time_(base_time) {
    int batch_size = n_block * thread_per_block;

    CU_CALL(cuInit, 0);
    CU_CALL(cuDeviceGet, &cu_device, 0);
    CU_CALL(cuDevicePrimaryCtxRetain, &cu_context, cu_device);
    CU_CALL(cuCtxSetCurrent, cu_context);

    init_sha1_kernel();

    for (auto &ptr: h)
        CU_CALL(cuMemAlloc, &ptr, batch_size * sizeof(u32));
}

CudaManager::~CudaManager() {
    if (cu_module != nullptr)
        cuModuleUnload(cu_module);

    if (cu_module_sha1 != nullptr)
        cuModuleUnload(cu_module_sha1);

    if (cu_result)
        cuMemFree(cu_result);

    CU_CALL(cuCtxSynchronize);

    for (auto &ptr: h) {
        if (ptr) cuMemFree(ptr);
    }

    if (cu_context != nullptr)
        cuDevicePrimaryCtxRelease(cu_device);
}

void CudaManager::gpu_proc_chunk(u32 n_chunk, u32 key_time0) const {
    void *args0[] = { &key_time0, (void*)&h[0], (void*)&h[1], (void*)&h[2], (void*)&h[3], (void*)&h[4] };
    CU_CALL(cuLaunchKernel,
            cu_proc_chunk0,
            n_block_, 1, 1,
            thread_per_block_, 1, 1,
            0, 0, args0, 0);

    for (u32 i = 1; i < n_chunk; i++) {
        size_t chunk_idx = i;
        void *args[] = { &chunk_idx, (void*)&h[0], (void*)&h[1], (void*)&h[2], (void*)&h[3], (void*)&h[4] };
        CU_CALL(cuLaunchKernel,
                cu_proc_chunk,
                n_block_, 1, 1,
                thread_per_block_, 1, 1,
                0, 0, args, 0);
    }
}

u32 CudaManager::load_key(const std::vector<u8> &pubkey) const {
    std::vector<u8> buf = pubkey;
    u32 buf_len = buf.size();

    // sha-1 padding
    int pad_zero = (56 - (buf_len + 1) % 64) % 64;
    u32 buf_len2 = buf_len + 1 + pad_zero + 8;

    buf.push_back(0x80);
    buf.resize(buf_len2, 0);

    buf_len *= 8;
    for (auto it = buf.rbegin(); buf_len && it != buf.rend(); it++) {
        *it = buf_len & 0xff;
        buf_len >>= 8;
    }

    // group buffer to 32-bit words
    for (u32 i = 0; i < buf_len2; i += 4) {
        std::swap(buf[i], buf[i + 3]);
        std::swap(buf[i + 1], buf[i + 2]);
    }

    DIE_ON_ERR(208 * sizeof(u32) >= buf_len2);
    CU_CALL(cuMemcpyHtoD, d_chunk_buffer, buf.data(), buf_len2);

    return buf_len2 / 64;
}

void CudaManager::test_key(const std::vector<u8> &key) {
    auto n_chunk = load_key(key);
    key_time0 = base_time_;

    gpu_proc_chunk(n_chunk, key_time0);
    gpu_pattern_check();
}

u32 CudaManager::get_result_time() const {
    u32 offset;
    CU_CALL(cuMemcpyDtoH, &offset, cu_result, sizeof(uint32_t));

    if (offset != UINT32_MAX)
        CU_CALL(cuMemsetD32, cu_result, UINT32_MAX, 1);

    return offset == UINT32_MAX ? UINT32_MAX : key_time0 - offset;
}
