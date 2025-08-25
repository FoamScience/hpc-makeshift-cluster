# A makeshift SLURM cluster

This is a primitive, easy to configure, SLURM "cluster" of Docker containers with:

- Ubuntu 24.04 as a base image
- SLURM installed and configured as follows:
  - One head node (`slurm-head` container, host name within cluster network: `head`,
    has the controller, REST API daemon and a `mariaDB` server,
    considered as a login node)
  - Four compute nodes (`slurm-compute-[1-4]` containers,
    host names within cluster network: `compute-[1-4]`, running `slurmd`)
- OpenMPI 4.1.6 (from apt repositories)
- Apptainer for nested container tech
- A preferred user named `slurmuser`, but can also run jobs as root
- SLURM-related services are started and managed by `supervisord`

## Instructions

### Building the cluster

1. Add any replicas of compute nodes to `docker-compose.yaml` file
   (if you want to, by default there are 4)
1. Tweak `slurm-image/slurm.conf` to account for the new compute nodes if any
1. `docker compose up -d --build` in the root folder of this repo to build images and deploy SLURM nodes.
1. `watch -n 0.1 -x docker logs slurm-head` and wait until the cluster is up and running. 

### Testing MPI/Apptainer integration

```bash
# Get into the head node as slurmuser
docker exec -it -u slurmuser slurm-head bash
# Pull an apptainer container that has OpenMPI
# /home/slurmuser path is shared between head and compute nodes
apptainer pull mpi.sif oras://ghcr.io/foamscience/ubuntu-24.04-openmpi-4.1.5:latest
# Compile a test script with the container, mind the '':
cat <<'EOF' > mpi_hello.c
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
EOF
apptainer run mpi.sif 'mpicc mpi_hello.c -o mpi_hello'

# Run a SLURM job with cluster MPI
cat <<'EOF' > mpi_job.sh
#!/bin/bash
#SBATCH --job-name=cluster_mpi_test
#SBATCH --nodes=2             # Number of nodes
#SBATCH --ntasks-per-node=2   # Tasks per node
#SBATCH --time=00:10:00       # Max run time
#SBATCH --output=cluster_mpi_test.log   # Output file
id
mpirun ./mpi_hello
EOF
sbatch mpi_job.sh

# Run a SLURM job with hybrid cluster/container MPI
# (This may complain about BTL modules missing, but should run)
cat <<'EOF' > mpi_apptainer_job.sh
#!/bin/bash
#SBATCH --job-name=cluster_apptainer_mpi_test
#SBATCH --nodes=2             # Number of nodes
#SBATCH --ntasks-per-node=2   # Tasks per node
#SBATCH --time=00:10:00       # Max run time
#SBATCH --output=cluster_apptainer_mpi_test.log   # Output file
id
mpirun apptainer run /home/slurmuser/mpi.sif /home/slurmuser/mpi_hello
EOF
sbatch mpi_apptainer_job.sh
```

### REST API usage

The SLURM REST API daemon is listening on port 6820 which is forwarded to your local machine.
To post a SLURM job through the REST endpoint, run the following commands (all on your local machine):

```bash
# Get an API token from the head node
export $(docker exec -it -u slurmuser slurm-head scontrol token | tr -d '\n\r')
# Create a job description:
cat <<'EOF' > job.json
{
    "script": "#!/bin/bash\nmpirun apptainer run /home/slurmuser/mpi.sif /home/slurmuser/mpi_hello",
    "job": {
        "environment": ["PATH=/bin/:/usr/bin/:/sbin/"],
        "name": "test apptainer job through slurmrestd",
        "current_working_directory": "/home/slurmuser",
        "tasks": 4
    }
}
EOF
# Prepare endpoint URL
export SLURM_REQ_URL=http://localhost:6820/slurm/v0.0.43
# Post a job
curl -s -X POST "$SLURM_REQ_URL/job/submit" \
    -H "X-SLURM-USER-NAME: slurmuser" \
    -H "X-SLURM-USER-TOKEN: $SLURM_JWT" \
    -H "Content-Type: application/json" \
    --data-binary "@job.json" | jq -r '.job_id'
```

