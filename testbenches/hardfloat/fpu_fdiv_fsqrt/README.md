# Content

- [Basic Test Flow](#section1)
- [Test Result](#section2)
- [Test Cases](#section3)

## Basic Test Flow <a name="section1"></a>

1. Change the parameters in *fpu_fdiv_fsqrt* and *test_fpu_fdiv_fsqrt*
- Change `expWidth` and `sigWidth` according to the width of inputs, following IEEE standard format requirements for floating point numbers
- Change `bits_per_iter_p` to 2 if you want to use Medium module for a faster speed but larger area, otherwise set it to 1 as default to use Small module
2. Add your input and output files in the correct paths, typically they should be put under the directory of your simulator, but if you use an absolute path in step 3 you can just skip this step
3. Make sure the input and output file paths in the *test_fpu_fdiv_fsqrt* are correct in this part ```tc_file = $fopen("test_input_32.txt", "r");
		out_file = $fopen("output_32.txt", "a");``` . If you are using the given input files, make sure the `tc_file` opens *"test_input_32.txt"* when testing 32 bits and *"test_input_64.txt"* when testing 64 bits
4. Run simulation!

## Test Result <a name="section2"></a>

- If you passed all the testcase the simulation will automatically finishes, and you will see a log in your output file saying it has finished immaculately:)
- If you failed some testcases during simulation
  - if you failed more than 20 cases it will automatically stops without testing the following cases
  - you can always see the specific cases that you failed in the log in your output file
  - likewise you can also see the same error logs in the console of your simulator


## Test Cases <a name="section3"></a>
- You can use the given test cases for 32 and 64 bits, and you are also welcome to make you own test cases for different inputs/rounding mode/operation/bit width, following the format as below!

    | Column 1 | Column 2 | Column 3 | Column 4 | Column 5 | Column 6 | Column 7 |
    | -------- | -------- | -------- | -------- | -------- | -------- | -------- |
    | control | roundingMode | sqrtOp | a | b | expectOut | expectExceptionFlags |
- Below are the testcases that we already have in the given testcases
  - Special Cases for fdiv       
  
    | input A  | input B  |
    | -------- | -------- |
    | 3.0      | 0        |
    | 0        | 3.0      |
    | 0        | 0        |
    | 3.0      | -0       |
    | -0       | 3.0      |
    | -0       | 0        |
    | Inf      | 3.0      |
    | Inf      | Inf      |
    | 3.0      | Inf      |
    | -Inf     | 3.0      |
    | -Inf     | Inf      |
    | NaN      | 3.0      |
    | -3.0     | NaN      |
    | NaN      | NaN      |
    | 0        | NaN      |
    | NaN      | Inf      |

  - Normal Cases for fdiv
  
    | input A  | input B  |
    | -------- | -------- |
    | 1.0      | 3.0      |
    | 1.0      | 1.0      |
    | 1.5      | 3.0      |
    | 0.7      | 6.6      |
    | 0.15     | 888888.0 |
    | subnormal1 | subnormal2 |
    | 3.0      | 1.0      |
    | 3.0      | 1.5      |
    | 6.6      | 0.7      |
    | 888888.0 | 0.15     |
    | -9.0     | 2.25     |
    | 1.0      | -3.0     |
    | -1.5     | 3.0      |
    | NaN      | NaN      |
    | 0        | NaN      |
    | subnormal2 | subnormal1 |
    
  - Special Cases for fsqrt
  
    | input A  | input B  |
    | -------- | -------- |
    | Inf      | 0        |
    | -Inf     | 0        |
    | 0        | 0        |
    | -0       | 0        |
    | NaN      | 0        |
    | -3.0     | 0        |
  
  - Normal Cases for fsqrt
  
    | input A  | input B  |
    | -------- | -------- |
    | 1.0      | 0        |
    | 0.04     | 0        |
    | 9.0      | 0        |
    | 10.25    | 0        |
    | 888888.0 | 0        |
    | subnormal| 0        |
