#include <tuple>

// Modified from https://stackoverflow.com/questions/7943525/is-it-possible-to-figure-out-the-parameter-type-and-return-type-of-a-lambda

// Fallback, anything with an operator()
template <typename T>
struct function_traits : public function_traits<decltype(&T::operator())> {
};

// Pointers to class members that are themselves functors.
// For example, in the following code:
// template <typename func_t>
// struct S {
//     func_t f;
// };
// template <typename func_t>
// S<func_t> make_s(func_t f) {
//     return S<func_t> { .f = f };
// }
//
// auto s = make_s([] (int, float) -> double { /* ... */ });
//
// function_traits<decltype(&s::f)> traits;
template <typename ClassType, typename T>
struct function_traits<T ClassType::*> : public function_traits<T> {
};

// Const class member functions
template <typename ClassType, typename ReturnType, typename... Args>
struct function_traits<ReturnType(ClassType::*)(Args...) const> : public function_traits<ReturnType(Args...)> {
};

// Non-const class member functions
template <typename ClassType, typename ReturnType, typename... Args>
struct function_traits<ReturnType(ClassType::*)(Args...)> : public function_traits<ReturnType(Args...)> {
};

// Reference types
template <typename T>
struct function_traits<T&> : public function_traits<T> {};
template <typename T>
struct function_traits<T*> : public function_traits<T> {};

// Free functions
template <typename ReturnType, typename... Args>
struct function_traits<ReturnType(Args...)> {
  // arity is the number of arguments.
  enum { arity = sizeof...(Args) };

  typedef std::tuple<Args...> ArgsTuple;
  typedef ReturnType result_type;

  template <size_t i>
  struct arg
  {
      typedef typename std::tuple_element<i, std::tuple<Args...>>::type type;
      // the i-th argument is equivalent to the i-th tuple element of a tuple
      // composed of those arguments.
  };
};

template <typename T>
struct nullary_function_traits {
  using traits = function_traits<T>;
  using result_type = typename traits::result_type;
};

template <typename T>
struct unary_function_traits {
  using traits = function_traits<T>;
  using result_type = typename traits::result_type;
  using arg1_t = typename traits::template arg<0>::type;
};

template <typename T>
struct binary_function_traits {
  using traits = function_traits<T>;
  using result_type = typename traits::result_type;
  using arg1_t = typename traits::template arg<0>::type;
  using arg2_t = typename traits::template arg<1>::type;
};

template <typename traits, typename func_t, typename index_t, size_t... INDEX>
typename traits::result_type
invoke_impl(func_t &f, char *const data[], const index_t strides[], int i,
            std::index_sequence<INDEX...>) {
  return f(*(typename traits::template arg<INDEX>::type*)(data[INDEX] + i * strides[INDEX])...);
}

template <typename func_t, typename index_t, typename traits = function_traits<func_t>>
typename traits::result_type
invoke(func_t &f, char *const data[], const index_t strides[], int i) {
  using Indices = std::make_index_sequence<traits::arity>;
  return invoke_impl<traits>(f, data, strides, i, Indices{});
}

int main() {
  auto f = [=](double x) mutable -> double { return x; };
  char *const d[1] = {nullptr};
  int s[1] = {0};
  invoke(f, d, s, 0);
}