#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>
#include <vector>

#include <cuda_runtime.h>

#define CHECK_CUDA(op)                                  \
  {                                                     \
    auto code = (op);                                   \
    if (code != cudaSuccess) {                          \
      throw std::runtime_error(cudaGetErrorName(code)); \
    }                                                   \
  }

template <typename T>
class Queue {
 public:
  void push(T t) {
    std::unique_lock<std::mutex> lock(mutex_);
    queue_.push_back(std::move(t));
    cv_.notify_all();
  }

  T pop() {
    std::unique_lock<std::mutex> lock(mutex_);
    cv_.wait(lock, [&]() { return !queue_.empty(); });
    T t = std::move(queue_.front());
    queue_.pop_front();
    return t;
  }

 private:
  std::deque<T> queue_;
  std::mutex mutex_;
  std::condition_variable cv_;
};

namespace {
const int dataSize = 256 * 1024; // 256KB
const int numTensors = 1000;
} // namespace

// auto FLAG = cudaEventDisableTiming | cudaEventInterprocess;
auto FLAG = cudaEventDisableTiming;

void code1() {
  CHECK_CUDA(cudaSetDevice(0));

  void* ptr;
  cudaStream_t stream;

  CHECK_CUDA(cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking));
  CHECK_CUDA(cudaMalloc(&ptr, dataSize));

  for (int i = 0; i < numTensors; i++) {
    cudaEvent_t event;
    CHECK_CUDA(cudaEventCreateWithFlags(&event, FLAG));
    CHECK_CUDA(cudaEventRecord(event, stream));
    CHECK_CUDA(cudaStreamWaitEvent(stream, event, 0));
    CHECK_CUDA(cudaEventDestroy(event));
  }

  CHECK_CUDA(cudaFree(ptr));
  CHECK_CUDA(cudaStreamDestroy(stream));
}

void code2() {
  CHECK_CUDA(cudaSetDevice(0));
  for (int i = 0; i < numTensors * 100; i++) {
    cudaEvent_t myEvent;
    CHECK_CUDA(cudaEventCreateWithFlags(&myEvent, FLAG));
    CHECK_CUDA(cudaEventDestroy(myEvent));
  }
}

int main() {
  Queue<cudaEvent_t> senderToReceiver;
  Queue<cudaEvent_t> receiverToSender;

  std::thread thread1(code1);
  std::thread thread2(code2);

  thread1.join();
  thread2.join();
}
