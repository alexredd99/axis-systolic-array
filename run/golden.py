import numpy as np
import argparse

def main(R, K, C, DIR):
    # Write R, C, K to a C header file
    with open("run/build/data/params.h", "w") as f:
        f.write(f"#define R {R}\n")
        f.write(f"#define K {K}\n")
        f.write(f"#define C {C}\n")

    # Generate random matrices
    k = np.random.randint(-128, 127, size=(K, C), dtype=np.int8)
    x = np.random.randint(-128, 127, size=(K, R), dtype=np.int8)
    a = np.random.randint(-2147483648, 2147483647, size=(R, C), dtype=np.int32)
    
    # Concatenate matrices
    with open(f"{DIR}/kxa.bin", "wb") as f:
        f.write(k.tobytes())
        f.write(x.tobytes())
        f.write(a.tobytes())
    
    y = x.T @ k + a # y(R,C) = x.T(R,K) @ k.T (K,C) + a(R,C)
    
    # Write y to binary file
    with open(f"{DIR}/y_exp.bin", "wb") as f:
        f.write(y.tobytes())

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate matrices and perform matrix operations.")
    parser.add_argument("--R", type=int, required=True, help="Number of rows in x and a")
    parser.add_argument("--K", type=int, required=True, help="Number of rows in k and columns in x")
    parser.add_argument("--C", type=int, required=True, help="Number of columns in k and a")
    parser.add_argument("--DIR", type=str, required=True, help="Full directory path to save matrices")
    args = parser.parse_args()
    
    main(args.R, args.K, args.C, args.DIR)