# !/usr/bin/env bash

# Set project name:
project="science-devel"

# Ensure a fresh start:
[[ -f "${project}.tar" ]] && rm -rf "${project}.tar"
[[ -f "${project}.sif" ]] && rm -rf "${project}.sif"

# Configure path to applications:
# CONTAINER=/usr/bin/podman
CONTAINER=/usr/bin/docker
APPTAINER=/usr/bin/apptainer

# Avoid the following warning:  WARN[0000] "/" is not a shared mount, this
# could cause issues or missing mounts with rootless containers.
# sudo mount --make-rshared /

# Build the container image and dump it to portable .tar file:
if [[ "${CONTAINER}" == *"podman"* ]]; then
    "${CONTAINER}" build -t "${project}" -f "Containerfile" .

    "${CONTAINER}" save -o "${project}.tar" "localhost/${project}"
else
    # Enable BuildKit
    export DOCKER_BUILDKIT=1

    "${CONTAINER}" build --network=host \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --progress=plain \
        -t "${project}" \
        -f "Containerfile" .

    "${CONTAINER}" save -o "${project}.tar" "${project}"
fi

# Convert container into apptainer:
"${APPTAINER}" build "${project}.sif" "docker-archive://${project}.tar"

# Remove tar-file:
# rm -rf "${project}.tar"

# After making sure it is working, remove the image (do not automate!):
# "${CONTAINER}" rmi "${project}"