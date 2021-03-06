#include <stdio.h>
#include <cublas_v2.h>
#include <curand.h>



#define TILE_SIZE 8

__global__ void mysgemm(int m, int n, int k, const float *A, const float *B, float* C) {

    /********************************************************************
     *
     * Compute C = A x B
     *   where A is a (m x k) matrix
     *   where B is a (k x n) matrix
     *   where C is a (m x n) matrix
     *******************************************************************/
	__shared__ float ds_A[TILE_SIZE][TILE_SIZE];
	__shared__ float ds_B[TILE_SIZE][TILE_SIZE];
	int bx = blockIdx.x;
	int by = blockIdx.y;
        int tx = threadIdx.x;
	int ty = threadIdx.y;
	int row = by * blockDim.y + ty;
	int col = bx * blockDim.x + tx;
	float pvalue = 0;
	for ( int p = 0; p < (k - 1)/TILE_SIZE+1; p++){
		if((p*TILE_SIZE + tx < k) && (row < m)){
			ds_A[ty][tx] = A[row * k + p * TILE_SIZE+tx];
		}
		else ds_A[ty][tx] = 0;
		
		if((p*TILE_SIZE + ty < k) && (col < n)){
			ds_B[ty][tx] = B[(p*TILE_SIZE+ty)*n + col];
		}
		else ds_B[ty][tx] = 0;
		__syncthreads();

		if(row < m && col < n){
			for (int i = 0; i <  TILE_SIZE; ++i){
				pvalue += ds_A[ty][i] * ds_B[i][tx];
			}
		}
		__syncthreads();

		if(row < m && col < n){
			C[row * n + col] = pvalue;
		}
	}
}

void basicSgemm(int m, int n, int k, const float *A, const float *B, float *C)
{
    const unsigned int BLOCK_SIZE = TILE_SIZE;
    dim3 dimGrid((n-1)/BLOCK_SIZE + 1, (m-1) / BLOCK_SIZE +1, 1);
    dim3 dimBlock(BLOCK_SIZE, BLOCK_SIZE, 1);
 
    mysgemm <<< dimGrid, dimBlock >>> (m, n, k, A, B, C);	
}

__device__ __forceinline__ float sigmoid (float a){
	return 1.0 / (1.0 + exp (-a));
}

__global__ void sigmoid_kernel (const float *C, float *Csig, int len){
	int stride = gridDim.x * blockDim.x;
    	int tid = blockDim.x * blockIdx.x + threadIdx.x;
	for(int i = tid; i < len; i += stride){
		Csig[i] = sigmoid (C[i]);
	}

}

void basicSigmoid(const float *C, float  *Csig, int len){
	dim3 dimBlock(256);
	int threadBlocks = (len + (dimBlock.x - 1)) / dimBlock.x;
	if (threadBlocks > 65520) threadBlocks = 65520;
	dim3 dimGrid(threadBlocks);

	sigmoid_kernel<<<dimGrid,dimBlock>>>(C, Csig, len);

}


__global__ void mysub(int m,int n, int k, const float *A, const float *B, float* C){
	for (int i = 0; i < (m * n); i++) {
		C[i] = A[i] - B[i];	
	}
}

void basicSub(int m,int n, int k, const float *A, const float *B, float* C){
    const unsigned int BLOCK_SIZE = TILE_SIZE;

    dim3 dimGrid((n-1)/BLOCK_SIZE + 1, (m-1) / BLOCK_SIZE + 1, 1);
    dim3 dimBlock(BLOCK_SIZE, BLOCK_SIZE, 1);

    mysub <<< dimGrid, dimBlock >>> (m,n, k, A, B, C);
}

