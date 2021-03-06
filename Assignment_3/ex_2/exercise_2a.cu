#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#define error 1e-6

#define NUM_ITERATIONS 1000
#define NUM_PARTICLES 10000
#define BLOCK_SIZE 256

struct particle {
    float position[3];
    float velocity[3];
};

double cpuSecond() {
    struct timeval tp;
    gettimeofday(&tp,NULL);
    return ((double)tp.tv_sec + (double)tp.tv_usec*1.e-6);
}

__host__ __device__ void uptdateParticle(particle *particula, int iter, int id, int num_p){
    //update the velocity:
    particula[id].velocity[0] = (3*id + iter) % num_p;
    particula[id].velocity[1] = (4*id + iter) % num_p;
    particula[id].velocity[2] = (5*id + iter) % num_p;

    //update the position:
    particula[id].position[0] = particula[id].position[0] + particula[id].velocity[0]; 
    particula[id].position[1] = particula[id].position[1] + particula[id].velocity[1]; 
    particula[id].position[2] = particula[id].position[2] + particula[id].velocity[2]; 
}

__global__ void timeStep(particle *particles, int iter, int num_p){
    const int id = threadIdx.x + blockIdx.x*blockDim.x;
    if(id < num_p){
        uptdateParticle(particles, iter, id, num_p);
    }
}

void init_Array(particle *particulas){
    for(int i = 0; i < NUM_PARTICLES; i++){
        particulas[i].position[0] = rand() % 1000;
        particulas[i].position[1] = rand() % 1000;
        particulas[i].position[2] = rand() % 1000;

        particulas[i].velocity[0] = rand() % 1000;
        particulas[i].velocity[1] = rand() % 1000;
        particulas[i].velocity[2] = rand() % 1000;
    }
}

int main( int argc, char *argv[]){

    
    bool bien = true;
    int GRID = (NUM_PARTICLES + BLOCK_SIZE - 1)/BLOCK_SIZE;


    double start_GPU, stop_GPU;
    double start_CPU, stop_CPU;
    double diferencia_CPU, diferencia_GPU;



    particle *particlesCPU = (particle*)malloc(NUM_PARTICLES * sizeof(particle));
    particle *particlesGPU;
    particle *resCPU;

    cudaMallocHost(&resCPU, NUM_PARTICLES * sizeof(particle));

    cudaMalloc(&particlesGPU, NUM_PARTICLES * sizeof(particle));

    init_Array(particlesCPU);

    cudaMemcpy(resCPU, particlesCPU, NUM_PARTICLES*sizeof(particle), cudaMemcpyHostToHost);


    // CPU part//

    start_CPU = cpuSecond();

    for(int i = 0; i < NUM_ITERATIONS; i++){
        for(int j = 0; j < NUM_PARTICLES; j++){
            uptdateParticle(particlesCPU, i, j, NUM_PARTICLES);
        }
    }


    stop_CPU = cpuSecond();
    diferencia_CPU = stop_CPU - start_CPU;

    // Finish CPU part

    //Start GPU part

    start_GPU = cpuSecond();
    

    for(int i = 0; i < NUM_ITERATIONS; i++){
        

        cudaMemcpy(particlesGPU, resCPU, sizeof(particle) * NUM_PARTICLES, cudaMemcpyHostToDevice);

        
        timeStep<<<GRID, BLOCK_SIZE>>>(particlesGPU, i, NUM_PARTICLES);
        cudaDeviceSynchronize();

        cudaMemcpy(resCPU, particlesGPU, NUM_PARTICLES * sizeof(particle), cudaMemcpyDeviceToHost);

    }

    stop_GPU = cpuSecond();

    diferencia_GPU = stop_GPU - start_GPU;

    for(int i = 0; i < NUM_PARTICLES && bien; i++){
        for(int dim = 0; dim < 3; dim++){
            if(fabs(particlesCPU[i].position[dim] - resCPU[i].position[dim]) > error ){
                bien = false;
                break;
            }
        }
    }

    printf("NUM_ITERATIONS: %d\n", NUM_ITERATIONS);
    printf("NUM_PARTICLES: %d\n", NUM_PARTICLES);
    printf("BLOCK_SIZE: %d\n", BLOCK_SIZE);
    if(bien){
        printf("datos correctos\n");
    }else{
        printf("datos incorrectos\n");
    }
        
    cudaFree(particlesGPU);
    cudaFreeHost(resCPU);
    delete[] particlesCPU;
    //delete[] resCPU;

    printf("Duration of the CPU: %f\n", diferencia_CPU);
    printf("Duration of the GPU: %f\n", diferencia_GPU);
    printf("--------------------------------------------\n");
    
    return 0;
}
