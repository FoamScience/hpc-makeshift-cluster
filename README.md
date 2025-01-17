# A makeshift SLURM cluster

This is a primitive, easy to configure, SLURM "cluster" of Docker containers that have:

- Ubuntu 20.04 as a base image
- SLURM installed and configured as follows:
  - One head node (`slurm-head` container, host name: `head`)
  - Four compute nodes (`slurm-compute-*` containers, host names: `compute-*`)
- OpenMPI 4.0.3 (from apt repositories)
- Apptainer for nested container tech
- A preferred user named `slurmuser`, but can also use root

## Instructions

### Building the cluster

1. Add any replicas of compute nodes to `docker-compose.yaml` file
   (if you want to, by default there are 4)
1. Tweak `slurm-image/slurm.conf` to account for the new compute nodes if any
1. `docker compose up -d --build` in the root folder of this repo.
1. Either `docker cp my.sif slurm-node:/home/slurmuser/my.sif` from your host or,
   - `apptainer pull /home/slurmuser/my.sif docker://ubuntu` on the head node
1. `docker exec -it -u slurmuser slurm-head bash`
   1. `srun -N 2 hostname` to see if SLURM works (should say compute-1 and compute-2).
   1. `srun -N 2 apptainer run my.sif hostname` to see if SLURM integrates with Apptainer.

### Testing MPI/Apptainer integration

You can use:
```bash
# Get into the head node as slurmuser
docker exec -it -u slurmuser slurm-head bash
# Pull an apptainer container that has OpenMPI
# The home folder of slurmuser is shared between head and compute nodes
docker pull mpi.sif oras://ghcr.io/foamscience/ubuntu-24.04-openmpi-4.1.5:latest
# Inside the container, compile a test script: 
mpicc mpi_hello.c -o mpi_hello
# Run SLURM job with host mpirun/mpiexec
sbatch mpi_job.sh
# Run SLURM job with container mpirun/mpiexec
sbatch mpi_apptainer_job.sh
# output.log and output_container.log should be identical (Of course, ignore SLURM config warnings)
```

An example test binary:
```c
// mpi_hello.c
#include <mpi.h>
#include <stdio.h>

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);
    int world_rank, world_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);
    printf("Hello from rank %d out of %d processors\n", world_rank, world_size);
    MPI_Finalize();
    return 0;
}
```

Example batch scripts for SLURM, demonstrating the use of the container MPI
and MPI installation from the host:

```bash
#!/bin/bash
#SBATCH --job-name=mpi_test_container
#SBATCH --nodes=2             # Number of nodes
#SBATCH --ntasks-per-node=2   # Tasks per node
#SBATCH --time=00:10:00       # Max run time
#SBATCH --output=output_apptainer.log   # Output file

# Run the MPI program through the container
id
mpirun apptainer run mpi.sif ./mpi_hello
```

```bash
#!/bin/bash
#SBATCH --job-name=mpi_test
#SBATCH --nodes=2             # Number of nodes
#SBATCH --ntasks-per-node=2   # Tasks per node
#SBATCH --time=00:10:00       # Max run time
#SBATCH --output=output_apptainer.log   # Output file

# Run the MPI program through the container
id
mpirun ./mpi_hello
```
